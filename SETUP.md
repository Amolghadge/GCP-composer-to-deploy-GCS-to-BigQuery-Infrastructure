# Setup Guide for GCP Composer DAG

## Prerequisites

Before starting, ensure you have:

1. **GCP Account** with billing enabled
2. **Service Account** created with the following roles:
   - Cloud Composer Worker
   - BigQuery Admin
   - Storage Admin
   - Service Account User

3. **Service Account Key** (JSON format) saved securely

4. **GitHub Repository** set up with the project code

5. **Local Development Tools**:
   ```bash
   - Terraform >= 1.0
   - Google Cloud SDK (gcloud CLI)
   - Python 3.8+
   - git
   ```

## Step 1: Local Development Setup

### 1.1 Clone the Repository

```bash
git clone <your-repo-url>
cd GCP\ composer\ DAG\ to\ move\ data\ from\ GCS\ to\ BigQuery
```

### 1.2 Create Python Virtual Environment

```bash
python3 -m venv venv
source venv/bin/activate  # On macOS/Linux
# or
venv\Scripts\activate  # On Windows
```

### 1.3 Install Python Dependencies

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

### 1.4 Validate DAG Locally

```bash
python -m py_compile dags/gcs_to_bigquery_dag.py
```

## Step 2: Configure Terraform

### 2.1 Update terraform.tfvars

Edit `terraform/terraform.tfvars` with your GCP project details:

```hcl
project_id             = "your-gcp-project-id"
region                 = "us-central1"
composer_env_name      = "gcs-to-bq-composer"
machine_type           = "n1-standard-4"
node_count             = 3
gcs_source_bucket      = "your-project-id-source"
gcs_archive_bucket     = "your-project-id-archive"
bigquery_dataset       = "data_warehouse"
bigquery_staging_table = "staging_data"
bigquery_main_table    = "main_data"
```

### 2.2 Authenticate with GCP

```bash
gcloud auth login
gcloud config set project <your-project-id>
```

### 2.3 Initialize Terraform

```bash
cd terraform
terraform init
```

### 2.4 Review Terraform Plan

```bash
terraform plan
```

## Step 3: Deploy Infrastructure

### 3.1 Apply Terraform Configuration

```bash
terraform apply
```

This will create:
- Cloud Composer environment
- GCS buckets (source and archive)
- BigQuery dataset
- Staging and main tables
- Service account with necessary IAM roles

### 3.2 Get Terraform Outputs

```bash
terraform output
```

Key outputs include:
- `composer_environment_name`: Your Cloud Composer environment name
- `airflow_uri`: URL to access Airflow UI
- `gcs_source_bucket`: Source bucket for data
- `bigquery_dataset_id`: Your BigQuery dataset

## Step 4: Configure GitHub Secrets

### 4.1 Generate Service Account Key

If you haven't already, generate a JSON key for your service account:

```bash
gcloud iam service-accounts keys create sa-key.json \
  --iam-account=cloud-composer-sa@<project-id>.iam.gserviceaccount.com
```

### 4.2 Add GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add the following secrets:

| Secret Name | Value |
|------------|-------|
| `GCP_PROJECT_ID` | Your GCP project ID |
| `GCP_SA_KEY` | Content of sa-key.json (entire JSON file) |
| `SLACK_WEBHOOK_URL` | (Optional) Your Slack webhook URL for notifications |

### 4.3 Secure the Key File

```bash
# Add to .gitignore (already done)
echo "sa-key.json" >> .gitignore

# Store key securely
rm sa-key.json  # Delete local copy after adding to GitHub
```

## Step 5: Deploy Using GitHub Actions

### 5.1 Create and Push to GitHub

```bash
git add .
git commit -m "Initial commit: GCP Composer DAG infrastructure"
git push origin main
```

### 5.2 Monitor GitHub Actions Workflow

1. Go to your GitHub repository
2. Click on "Actions" tab
3. Select "Deploy GCS to BigQuery Infrastructure"
4. Watch the workflow progress

The workflow will:
- Validate Terraform configuration
- Validate Airflow DAG syntax
- Deploy infrastructure (on main branch)
- Deploy DAG to Cloud Composer
- Run integration tests

## Step 6: Access Airflow UI

### 6.1 Get Airflow URL

```bash
gcloud composer environments describe gcs-to-bq-composer \
  --location us-central1 \
  --format='value(config.airflowUri)'
```

### 6.2 Access UI

1. Click the Airflow URI link or open in browser
2. You should see the DAG: `gcs_to_bigquery_dag`
3. The DAG is scheduled to run daily at 2 AM UTC

## Step 7: Manual Testing

### 7.1 Upload Test Data

```bash
# Create test CSV
cat > test_data.csv << 'EOF'
id,data,load_timestamp
1,"{""name"":""Test 1""}",2025-11-19T00:00:00Z
2,"{""name"":""Test 2""}",2025-11-19T00:00:00Z
EOF

# Upload to GCS
gsutil cp test_data.csv gs://<project-id>-source/data/test_data.csv
```

### 7.2 Trigger DAG Manually

From Cloud Composer, trigger the DAG:

```bash
gcloud composer environments run gcs-to-bq-composer \
  --location us-central1 \
  dags trigger -- gcs_to_bigquery_dag
```

### 7.3 Monitor Execution

1. Go to Airflow UI
2. Click on `gcs_to_bigquery_dag`
3. Click "Grid" or "Tree" view to see task execution
4. Click on individual tasks to view logs

## Step 8: Verify Data Pipeline

### 8.1 Check BigQuery Tables

```bash
# Check staging table
bq query --use_legacy_sql=false '
SELECT COUNT(*) as count FROM `<project-id>.data_warehouse.staging_data`
'

# Check main table
bq query --use_legacy_sql=false '
SELECT COUNT(*) as count FROM `<project-id>.data_warehouse.main_data`
'
```

### 8.2 Check GCS Archive

```bash
# Verify files archived
gsutil ls gs://<project-id>-archive/data/
```

## Troubleshooting

### Issue: DAG not appearing in Airflow UI

**Solution:**
1. Check DAG syntax: `python -m py_compile dags/gcs_to_bigquery_dag.py`
2. Wait 1-2 minutes for DAG to be picked up
3. Check Airflow logs in Cloud Composer

### Issue: Permission Denied Errors

**Solution:**
1. Verify service account has required roles
2. Check GCS bucket permissions
3. Verify BigQuery dataset permissions

```bash
# Check IAM bindings
gcloud projects get-iam-policy <project-id>
```

### Issue: Cloud Composer Creation Failing

**Solution:**
1. Ensure all required APIs are enabled
2. Check quota limits
3. Verify network connectivity

```bash
# Enable APIs
gcloud services enable composer.googleapis.com
gcloud services enable bigquery.googleapis.com
gcloud services enable storage.googleapis.com
```

## Monitoring and Maintenance

### Regular Checks

1. **Weekly**: Review DAG execution logs in Airflow UI
2. **Monthly**: Monitor Cloud Composer resource usage
3. **Quarterly**: Review and optimize DAG performance

### Scaling Up

To increase capacity, update `terraform.tfvars`:

```hcl
machine_type = "n1-standard-8"  # Larger machine
node_count   = 5                # More nodes
```

Then run:

```bash
cd terraform
terraform apply
```

## Cleanup and Teardown

### Remove All Infrastructure

⚠️ **Warning**: This will delete all resources including data!

```bash
cd terraform
terraform destroy
```

## Support and Documentation

- [Cloud Composer Docs](https://cloud.google.com/composer/docs)
- [Apache Airflow Docs](https://airflow.apache.org/docs/)
- [BigQuery Docs](https://cloud.google.com/bigquery/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

## Next Steps

1. ✅ Customize the DAG for your data sources
2. ✅ Add additional data quality checks
3. ✅ Implement error handling and alerting
4. ✅ Set up data lineage tracking
5. ✅ Configure backups and disaster recovery
