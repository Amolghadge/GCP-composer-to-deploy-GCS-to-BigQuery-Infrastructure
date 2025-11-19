# Quick Start Guide

## 5-Minute Quick Start

### Step 1: Prepare GCP Project (5 min)

```bash
# Set your project ID
export PROJECT_ID="your-project-id"

# Enable required APIs
gcloud services enable composer.googleapis.com \
  --project=$PROJECT_ID
gcloud services enable bigquery.googleapis.com \
  --project=$PROJECT_ID
gcloud services enable storage.googleapis.com \
  --project=$PROJECT_ID

# Create service account
gcloud iam service-accounts create cloud-composer-sa \
  --display-name="Cloud Composer Service Account" \
  --project=$PROJECT_ID

# Assign roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:cloud-composer-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/composer.worker"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:cloud-composer-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/bigquery.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:cloud-composer-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.admin"
```

### Step 2: Configure Terraform (2 min)

```bash
# Edit terraform.tfvars
cat > terraform/terraform.tfvars << EOF
project_id             = "$PROJECT_ID"
region                 = "us-central1"
composer_env_name      = "gcs-to-bq-composer"
machine_type           = "n1-standard-4"
node_count             = 3
python_version         = "3"
airflow_version        = "2"
gcs_source_bucket      = "${PROJECT_ID}-source"
gcs_archive_bucket     = "${PROJECT_ID}-archive"
bigquery_dataset       = "data_warehouse"
bigquery_staging_table = "staging_data"
bigquery_main_table    = "main_data"
EOF

# Initialize Terraform
cd terraform
terraform init
```

### Step 3: Deploy Infrastructure (depends on GCP)

```bash
# This takes 20-30 minutes
terraform apply -auto-approve
```

### Step 4: Deploy DAG

```bash
# Get the DAG folder
DAG_FOLDER=$(terraform output -raw composer_dag_folder)

# Upload DAG
gsutil cp ../dags/gcs_to_bigquery_dag.py $DAG_FOLDER/

echo "✅ DAG deployed!"
```

### Step 5: Monitor

```bash
# Get Airflow UI URL
AIRFLOW_URI=$(terraform output -raw airflow_uri)
echo "Open Airflow UI: $AIRFLOW_URI"
```

## Using Make Commands

```bash
# One-line setup
make setup validate plan apply

# Or step by step
make setup
make validate
make plan
make apply
make deploy-dag
make monitor
```

## GitHub Actions Deployment

### Prerequisites
1. GitHub repository initialized
2. GitHub secrets configured:
   - `GCP_PROJECT_ID`
   - `GCP_SA_KEY`

### Deploy
```bash
git add .
git commit -m "Deploy infrastructure"
git push origin main
# Watch GitHub Actions for progress
```

## Verify Deployment

```bash
# 1. Check GCS buckets
gsutil ls -p $PROJECT_ID | grep source

# 2. Check BigQuery
bq ls --project_id=$PROJECT_ID

# 3. Check Cloud Composer
gcloud composer environments list --location=us-central1

# 4. Access Airflow UI
make monitor
```

## Test the Pipeline

```bash
# 1. Upload test data
make test-data-upload

# 2. Trigger DAG
make trigger-dag

# 3. Monitor execution
make monitor

# 4. Check results
make bq-query-main
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Terraform fails | Check API enablement: `gcloud services list --enabled` |
| DAG not visible | Wait 1-2 minutes, refresh Airflow UI |
| No files found | Check GCS path: `gsutil ls gs://$PROJECT_ID-source/data/` |
| Permission denied | Verify service account roles in IAM |

## Next Steps

1. ✅ Customize DAG for your data sources
2. ✅ Set up alerting and monitoring
3. ✅ Configure backups and disaster recovery
4. ✅ Implement data quality framework
5. ✅ Document your data lineage

## Support

- 📖 [Full Setup Guide](./SETUP.md)
- 📖 [DAG Documentation](./DAG_DOCUMENTATION.md)
- 📖 [README](./README.md)
- 🔗 [Cloud Composer Docs](https://cloud.google.com/composer/docs)
- 🔗 [Airflow Docs](https://airflow.apache.org/docs/)
