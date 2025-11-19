# GCP Composer DAG - GCS to BigQuery Data Movement

This project creates a complete infrastructure for moving data from Google Cloud Storage (GCS) to BigQuery using Cloud Composer (managed Apache Airflow) with Terraform, and includes GitHub Actions for automated deployment.

## Project Structure

```
.
├── terraform/
│   ├── main.tf                 # Main Terraform configuration
│   ├── variables.tf            # Variable definitions
│   ├── outputs.tf              # Output definitions
│   ├── provider.tf             # GCP provider configuration
│   ├── composer.tf             # Cloud Composer setup
│   └── terraform.tfvars        # Terraform variables (update with your values)
├── dags/
│   └── gcs_to_bigquery_dag.py  # Airflow DAG definition
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions deployment workflow
├── README.md                   # Project documentation
└── .gitignore                  # Git ignore rules
```

## Prerequisites

1. **GCP Account** - With billing enabled
2. **Service Account** - With appropriate permissions:
   - Composer Worker
   - BigQuery Admin
   - Storage Admin
3. **GitHub Repository** - With the following secrets configured:
   - `GCP_PROJECT_ID`
   - `GCP_SA_KEY` (Service Account key as JSON)
4. **Local Tools**:
   - Terraform >= 1.0
   - gcloud CLI
   - Python 3.8+

## Setup Instructions

### 1. Configure Terraform Variables

Update `terraform/terraform.tfvars` with your GCP project details:

```hcl
project_id   = "your-project-id"
region       = "us-central1"
composer_env = "gcs-to-bq-composer"
```

### 2. Deploy Infrastructure with Terraform

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

### 3. Configure GitHub Secrets

Add the following secrets to your GitHub repository:
- `GCP_PROJECT_ID`: Your GCP project ID
- `GCP_SA_KEY`: Service Account key as JSON

### 4. Deploy DAG via GitHub Actions

Push changes to trigger the workflow:

```bash
git add .
git commit -m "Deploy GCS to BigQuery DAG"
git push origin main
```

## DAG Workflow

The `gcs_to_bigquery_dag` performs the following operations:

1. **Check GCS Bucket** - Verifies if data file exists in GCS
2. **Load Data to BigQuery** - Transfers data from GCS to BigQuery staging table
3. **Validate Data** - Runs data quality checks
4. **Archive Data** - Moves processed file to archive bucket

## Monitoring

Access the Airflow UI through Cloud Composer:

1. Open GCP Console → Cloud Composer
2. Click on your environment
3. Click "Airflow UI" link
4. Locate and monitor the DAG: `gcs_to_bigquery_dag`

## Configuration

### GCS Bucket Details
- **Source Bucket**: `gs://{project-id}-source/`
- **Archive Bucket**: `gs://{project-id}-archive/`

### BigQuery Dataset
- **Dataset ID**: `data_warehouse`
- **Staging Table**: `staging_data`
- **Production Table**: `main_data`

## Scaling Considerations

- Adjust machine types in `composer.tf` for different workloads
- Modify node count based on DAG complexity
- Configure autoscaling policies as needed

## Troubleshooting

### DAG not appearing in Airflow UI
- Check DAG syntax with: `python -m py_compile dags/gcs_to_bigquery_dag.py`
- Verify DAG is in Composer environment's DAG folder
- Check Cloud Composer logs in GCP Console

### Permission Errors
- Ensure service account has required roles
- Verify BigQuery dataset permissions
- Check GCS bucket access

## Cost Optimization

- Use Preemptible VMs for non-critical workloads
- Schedule DAGs during off-peak hours
- Monitor Cloud Composer resource usage

## Security Best Practices

1. Use service accounts instead of user credentials
2. Enable VPC-SC if available
3. Encrypt data at rest and in transit
4. Use separate environments for dev/staging/prod
5. Rotate service account keys regularly

## Support

For issues or questions:
1. Check [Cloud Composer Documentation](https://cloud.google.com/composer/docs)
2. Review [Apache Airflow Documentation](https://airflow.apache.org/docs/)
3. Check [BigQuery Documentation](https://cloud.google.com/bigquery/docs)
