# Deployment Checklist

## Pre-Deployment

- [ ] GCP account with billing enabled
- [ ] Service account created with necessary roles
- [ ] Service account key (JSON) generated and secured
- [ ] GitHub repository initialized
- [ ] GitHub secrets configured:
  - [ ] `GCP_PROJECT_ID`
  - [ ] `GCP_SA_KEY`
  - [ ] `SLACK_WEBHOOK_URL` (optional)

## Local Setup

- [ ] Python 3.8+ installed
- [ ] Terraform >= 1.0 installed
- [ ] Google Cloud SDK installed
- [ ] Git installed
- [ ] Virtual environment created: `python3 -m venv venv`
- [ ] Dependencies installed: `pip install -r requirements.txt`

## Configuration

- [ ] `terraform/terraform.tfvars` updated with correct values:
  - [ ] `project_id` set to your GCP project
  - [ ] `region` set (default: us-central1)
  - [ ] `gcs_source_bucket` and `gcs_archive_bucket` configured
  - [ ] BigQuery dataset and table names configured

- [ ] GCP authentication configured: `gcloud auth login`
- [ ] Project set: `gcloud config set project YOUR_PROJECT_ID`

## Terraform Validation

- [ ] Terraform initialized: `cd terraform && terraform init`
- [ ] Configuration valid: `terraform validate`
- [ ] No formatting issues: `terraform fmt -recursive`
- [ ] Plan reviewed: `terraform plan`
- [ ] No blocking issues in plan output

## DAG Validation

- [ ] DAG syntax valid: `python -m py_compile dags/gcs_to_bigquery_dag.py`
- [ ] DAG parses correctly: `python dags/gcs_to_bigquery_dag.py`
- [ ] Environment variables documented in DAG

## Deployment (Infrastructure)

- [ ] All validations passed
- [ ] Ready to apply: `terraform apply`
- [ ] Wait for Cloud Composer creation (20-30 minutes)
- [ ] Verify all resources created:
  - [ ] Cloud Composer environment
  - [ ] GCS buckets (source and archive)
  - [ ] BigQuery dataset and tables
  - [ ] Service account and IAM roles

## DAG Deployment

- [ ] Get DAG folder: `terraform output composer_dag_folder`
- [ ] Upload DAG: `gsutil cp dags/gcs_to_bigquery_dag.py <dag_folder>/`
- [ ] Wait 1-2 minutes for DAG to be registered
- [ ] DAG visible in Airflow UI

## Post-Deployment Testing

### Basic Verification
- [ ] Airflow UI accessible: `terraform output airflow_uri`
- [ ] DAG visible in Airflow UI: `gcs_to_bigquery_dag`
- [ ] DAG has no errors in UI

### Data Pipeline Testing
- [ ] Test data uploaded to GCS: `gsutil cp test_data.csv gs://<bucket>/data/`
- [ ] DAG triggered manually
- [ ] All tasks executed successfully
- [ ] Data appears in staging table
- [ ] Data merged to main table
- [ ] Files archived to archive bucket

### Verification Queries
- [ ] Staging table has records: `bq query --use_legacy_sql=false 'SELECT COUNT(*) FROM <project>.data_warehouse.staging_data'`
- [ ] Main table has records: `bq query --use_legacy_sql=false 'SELECT COUNT(*) FROM <project>.data_warehouse.main_data'`
- [ ] GCS archive has files: `gsutil ls gs://<bucket>-archive/data/`

## GitHub Actions Setup

- [ ] GitHub repository connected
- [ ] GitHub secrets verified
- [ ] Workflow file present: `.github/workflows/deploy.yml`
- [ ] First push to main branch triggers workflow
- [ ] Workflow completes successfully
- [ ] DAG deployed via GitHub Actions

## Monitoring Setup

- [ ] Airflow alerts configured (optional)
- [ ] Slack notifications enabled (optional)
- [ ] Cloud Logging configured (optional)
- [ ] BigQuery cost monitoring enabled (optional)

## Documentation

- [ ] README.md reviewed and updated
- [ ] SETUP.md customized for your environment
- [ ] DAG_DOCUMENTATION.md updated with specifics
- [ ] Team documentation created
- [ ] Runbooks for common issues documented

## Security Review

- [ ] Service account permissions follow least privilege principle
- [ ] Sensitive files in .gitignore:
  - [ ] `*.tfstate`
  - [ ] `*.tfvars` (if contains secrets)
  - [ ] `sa-key.json`
  - [ ] `.env` files

- [ ] GitHub secrets properly masked in logs
- [ ] No hardcoded credentials in code
- [ ] IAM bindings reviewed
- [ ] VPC-SC enabled (if available in organization)

## Performance & Cost

- [ ] Resource sizing appropriate for data volume
- [ ] BigQuery cost estimates reviewed
- [ ] Cloud Composer resource usage monitored
- [ ] Retention policies set for archive buckets
- [ ] Unused resources identified and cleaned up

## Backup & Disaster Recovery

- [ ] Terraform state backed up
- [ ] BigQuery export configuration set (optional)
- [ ] GCS lifecycle policies configured (optional)
- [ ] Recovery procedure documented
- [ ] DR testing scheduled

## Handover Checklist

- [ ] Operations team trained on DAG
- [ ] Troubleshooting guide provided
- [ ] On-call contact information documented
- [ ] Escalation procedures defined
- [ ] Access granted to required personnel

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Developer | | | |
| Ops Lead | | | |
| Manager | | | |

---

## Rollback Procedure (if needed)

1. Stop all DAG runs in Airflow UI
2. Note current data state from BigQuery
3. Run: `terraform destroy`
4. Restore from backups if needed
5. Document lessons learned

## Post-Production

- [ ] Monitor DAG execution daily for first week
- [ ] Review logs for any warnings
- [ ] Optimize performance based on initial runs
- [ ] Schedule follow-up review (30 days)
- [ ] Plan incremental improvements
