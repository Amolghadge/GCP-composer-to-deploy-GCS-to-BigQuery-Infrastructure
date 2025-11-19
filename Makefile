.PHONY: help setup validate plan apply deploy-dag test clean destroy

help:
	@echo "GCP Composer DAG - Makefile Commands"
	@echo "====================================="
	@echo "make setup              - Setup local development environment"
	@echo "make validate           - Validate Terraform and DAG syntax"
	@echo "make plan               - Show Terraform execution plan"
	@echo "make apply              - Apply Terraform configuration"
	@echo "make deploy-dag         - Deploy DAG to Cloud Composer"
	@echo "make test               - Run tests"
	@echo "make clean              - Clean temporary files"
	@echo "make destroy            - Destroy infrastructure (WARNING!)"
	@echo "make monitor            - Monitor DAG execution"
	@echo "make logs               - Fetch Cloud Composer logs"

setup:
	@echo "Setting up development environment..."
	python3 -m venv venv
	. venv/bin/activate && pip install --upgrade pip
	. venv/bin/activate && pip install -r requirements.txt
	cd terraform && terraform init
	@echo "Setup complete! Activate venv with: source venv/bin/activate"

validate:
	@echo "Validating Terraform configuration..."
	cd terraform && terraform validate
	@echo ""
	@echo "Validating DAG syntax..."
	python -m py_compile dags/gcs_to_bigquery_dag.py
	@echo "All validations passed!"

format:
	@echo "Formatting Terraform files..."
	cd terraform && terraform fmt -recursive

plan:
	@echo "Creating Terraform plan..."
	cd terraform && terraform plan -out=tfplan

apply:
	@echo "Applying Terraform configuration..."
	cd terraform && terraform apply

destroy:
	@echo "WARNING: This will destroy all infrastructure!"
	@read -p "Type 'destroy-gcs-bigquery' to confirm: " confirm; \
	if [ "$$confirm" = "destroy-gcs-bigquery" ]; then \
		cd terraform && terraform destroy; \
	else \
		echo "Cancelled"; \
	fi

deploy-dag:
	@echo "Deploying DAG to Cloud Composer..."
	@read -p "Enter GCP Project ID: " project_id; \
	read -p "Enter Composer Environment Name (default: gcs-to-bq-composer): " composer_env; \
	composer_env=$${composer_env:-gcs-to-bq-composer}; \
	dag_folder=$$(gcloud composer environments describe $$composer_env \
		--project=$$project_id \
		--location=us-central1 \
		--format='value(config.dagGcsPrefix)'); \
	gsutil cp dags/gcs_to_bigquery_dag.py $$dag_folder/; \
	echo "DAG deployed to $$dag_folder"

test-dag-local:
	@echo "Testing DAG locally..."
	export AIRFLOW_HOME=$$(pwd) && \
	export AIRFLOW__CORE__DAGS_FOLDER=$$(pwd)/dags && \
	export AIRFLOW__CORE__LOAD_EXAMPLES=False && \
	python dags/gcs_to_bigquery_dag.py
	@echo "DAG parsing test passed!"

test-data-upload:
	@echo "Uploading test data to GCS..."
	@read -p "Enter GCP Project ID: " project_id; \
	bucket="gs://$$project_id-source"; \
	echo "id,data,load_timestamp" > /tmp/test.csv; \
	echo '1,"{""test"":""data1""}",2025-11-19T00:00:00Z' >> /tmp/test.csv; \
	echo '2,"{""test"":""data2""}",2025-11-19T00:00:00Z' >> /tmp/test.csv; \
	gsutil cp /tmp/test.csv $$bucket/data/test_$(shell date +%s).csv; \
	echo "Test data uploaded to $$bucket/data/"

monitor:
	@echo "Getting Cloud Composer Airflow URI..."
	@read -p "Enter GCP Project ID: " project_id; \
	read -p "Enter Composer Environment Name (default: gcs-to-bq-composer): " composer_env; \
	composer_env=$${composer_env:-gcs-to-bq-composer}; \
	airflow_uri=$$(gcloud composer environments describe $$composer_env \
		--project=$$project_id \
		--location=us-central1 \
		--format='value(config.airflowUri)'); \
	echo "Opening Airflow UI: $$airflow_uri"; \
	open $$airflow_uri || xdg-open $$airflow_uri

logs:
	@echo "Fetching Cloud Composer logs..."
	@read -p "Enter GCP Project ID: " project_id; \
	read -p "Enter Composer Environment Name (default: gcs-to-bq-composer): " composer_env; \
	composer_env=$${composer_env:-gcs-to-bq-composer}; \
	gcloud composer environments logs read $$composer_env \
		--project=$$project_id \
		--location=us-central1 \
		--limit=50

outputs:
	@echo "Terraform Outputs:"
	@cd terraform && terraform output

state:
	@echo "Terraform State:"
	@cd terraform && terraform show

clean:
	@echo "Cleaning up..."
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type f -name ".DS_Store" -delete
	rm -rf venv/
	rm -rf build/ dist/ *.egg-info/
	rm -f /tmp/test.csv
	@echo "Cleanup complete!"

gcs-list:
	@echo "Listing GCS buckets..."
	@read -p "Enter GCP Project ID: " project_id; \
	gsutil ls -p $$project_id

bq-datasets:
	@echo "Listing BigQuery datasets..."
	@read -p "Enter GCP Project ID: " project_id; \
	bq ls --project_id=$$project_id

bq-tables:
	@read -p "Enter GCP Project ID: " project_id; \
	read -p "Enter Dataset ID (default: data_warehouse): " dataset; \
	dataset=$${dataset:-data_warehouse}; \
	echo "Tables in $$dataset:"; \
	bq ls --project_id=$$project_id $$dataset

bq-query-staging:
	@read -p "Enter GCP Project ID: " project_id; \
	echo "SELECT COUNT(*) as count FROM \`$$project_id.data_warehouse.staging_data\`" | bq query --use_legacy_sql=false --project_id=$$project_id

bq-query-main:
	@read -p "Enter GCP Project ID: " project_id; \
	echo "SELECT COUNT(*) as count FROM \`$$project_id.data_warehouse.main_data\`" | bq query --use_legacy_sql=false --project_id=$$project_id

trigger-dag:
	@read -p "Enter GCP Project ID: " project_id; \
	read -p "Enter Composer Environment Name (default: gcs-to-bq-composer): " composer_env; \
	composer_env=$${composer_env:-gcs-to-bq-composer}; \
	echo "Triggering DAG..."; \
	gcloud composer environments run $$composer_env \
		--project=$$project_id \
		--location=us-central1 \
		dags trigger -- gcs_to_bigquery_dag; \
	echo "DAG triggered!"

.DEFAULT_GOAL := help
