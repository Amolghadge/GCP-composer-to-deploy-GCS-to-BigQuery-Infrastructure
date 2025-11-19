# GCP Composer DAG - Complete Documentation Index

Welcome! This project provides a production-ready infrastructure for moving data from Google Cloud Storage (GCS) to BigQuery using Cloud Composer (Apache Airflow).

## 🚀 Quick Navigation

### First Time? Start Here
1. **[QUICKSTART.md](./QUICKSTART.md)** - Get up and running in 5 minutes
2. **[SETUP.md](./SETUP.md)** - Detailed step-by-step setup guide
3. **[README.md](./README.md)** - Project overview and features

### Planning & Pre-Deployment
- **[PROJECT_SUMMARY.md](./PROJECT_SUMMARY.md)** - Complete project overview
- **[DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md)** - Pre-deployment verification
- **[DAG_DOCUMENTATION.md](./DAG_DOCUMENTATION.md)** - DAG specifications and details

### Development & Operations
- **[Makefile](./Makefile)** - Helpful command shortcuts
- **[.github/workflows/deploy.yml](./.github/workflows/deploy.yml)** - Production deployment
- **[.github/workflows/quality.yml](./.github/workflows/quality.yml)** - Code quality checks

## 📚 Documentation Structure

### README Files
| File | Purpose | Read Time |
|------|---------|-----------|
| [README.md](./README.md) | Main project documentation | 10 min |
| [PROJECT_SUMMARY.md](./PROJECT_SUMMARY.md) | Comprehensive project overview | 15 min |
| [QUICKSTART.md](./QUICKSTART.md) | 5-minute quick start | 5 min |
| [SETUP.md](./SETUP.md) | Detailed setup instructions | 30 min |
| [DAG_DOCUMENTATION.md](./DAG_DOCUMENTATION.md) | DAG specifications | 20 min |
| [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md) | Pre-deployment checklist | 10 min |

### Code Files
| Directory | Files | Purpose |
|-----------|-------|---------|
| `terraform/` | `*.tf` files | Infrastructure as Code |
| `dags/` | `gcs_to_bigquery_dag.py` | Airflow DAG definition |
| `.github/workflows/` | `*.yml` files | CI/CD automation |
| `./` | `Makefile`, `requirements.txt` | Development tools |

## 🏗️ Architecture Overview

```
GitHub Repository
    ↓
GitHub Actions
    ├─ Quality Checks (pull requests)
    └─ Deployment (main branch)
        ↓
    GCP Cloud Composer
    ├─ Airflow DAG
    ├─ Task Orchestration
    └─ Monitoring
        ↓
    Data Pipeline
    ├─ GCS Source
    ├─ BigQuery Staging
    ├─ Data Validation
    ├─ BigQuery Main
    └─ GCS Archive
```

## 🎯 Common Tasks

### Setting Up
```bash
# Quick setup (5 minutes)
make setup
make validate
make plan

# Full setup (30 minutes)
cd terraform && terraform init
terraform plan
terraform apply
```

### Deploying
```bash
# Local deployment
make apply
make deploy-dag

# GitHub Actions deployment
git push origin main
# Watch GitHub Actions tab
```

### Operating
```bash
# Access Airflow UI
make monitor

# View logs
make logs

# Query results
make bq-query-main

# Trigger DAG
make trigger-dag
```

### Testing
```bash
# Validate syntax
make validate

# Upload test data
make test-data-upload

# Run unit tests
make test-dag-local
```

## 📋 Key Features

### ✨ Infrastructure (Terraform)
- Automated GCP resource creation
- Cloud Composer environment setup
- BigQuery dataset and tables
- Service account with IAM roles
- GCS buckets for source and archive

### 🔄 Data Pipeline (Airflow)
- 6-task DAG with error handling
- Data validation and quality checks
- Automatic file archival
- Execution notifications
- Daily scheduling (customizable)

### 🚀 CI/CD (GitHub Actions)
- Automatic Terraform validation
- DAG syntax checking
- Code quality enforcement
- Security scanning
- Automated deployment on merge

## 🔐 Prerequisites

### Required
- ✅ GCP account with billing enabled
- ✅ Service account with appropriate roles
- ✅ GitHub repository initialized
- ✅ Local tools (Terraform, gcloud CLI, Python 3.8+)

### Recommended
- ✅ Understanding of Apache Airflow basics
- ✅ GCP cloud familiarity
- ✅ Git and GitHub experience
- ✅ Basic Terraform knowledge

## 🛠️ Configuration

### Edit terraform/terraform.tfvars
```hcl
project_id             = "your-project-id"
region                 = "us-central1"
composer_env_name      = "gcs-to-bq-composer"
machine_type           = "n1-standard-4"
node_count             = 3
gcs_source_bucket      = "your-project-id-source"
gcs_archive_bucket     = "your-project-id-archive"
```

### Configure GitHub Secrets
1. Go to: Settings → Secrets and variables → Actions
2. Add:
   - `GCP_PROJECT_ID` - Your GCP project ID
   - `GCP_SA_KEY` - Service account key (JSON)
   - `SLACK_WEBHOOK_URL` - (Optional) Slack notifications

## 📊 Data Flow

```
CSV File Upload
    ↓
GCS Source Bucket
    ↓
Airflow DAG Triggered (Daily 2 AM UTC)
    ├─ Check files exist
    ├─ Load to BigQuery staging
    ├─ Validate data quality
    ├─ Merge to main table
    ├─ Archive source file
    └─ Send notification
    ↓
BigQuery Main Table (Production Data)
GCS Archive Bucket (Processed Files)
```

## 🚨 Troubleshooting

### Common Issues
| Issue | Solution | More Info |
|-------|----------|-----------|
| Terraform fails | Enable APIs: `gcloud services enable ...` | [SETUP.md](./SETUP.md) |
| DAG not visible | Wait 1-2 minutes, refresh Airflow UI | [DAG_DOCUMENTATION.md](./DAG_DOCUMENTATION.md) |
| Permission denied | Verify service account roles | [SETUP.md](./SETUP.md) |
| No files found | Check GCS path: `gs://bucket/data/` | [DAG_DOCUMENTATION.md](./DAG_DOCUMENTATION.md) |

See [SETUP.md](./SETUP.md) for detailed troubleshooting.

## 📖 Learning Resources

### Official Documentation
- [Cloud Composer](https://cloud.google.com/composer/docs)
- [Apache Airflow](https://airflow.apache.org/docs/)
- [BigQuery](https://cloud.google.com/bigquery/docs)
- [Terraform](https://www.terraform.io/docs)
- [GitHub Actions](https://docs.github.com/en/actions)

### Project Documentation
- **Infrastructure**: [terraform/main.tf](./terraform/main.tf)
- **DAG Logic**: [dags/gcs_to_bigquery_dag.py](./dags/gcs_to_bigquery_dag.py)
- **Workflows**: [.github/workflows/](./github/workflows/)

## 🔄 Deployment Options

### Option 1: Quick Local Deployment (20-30 min)
```bash
make setup
make plan
make apply
make deploy-dag
```

### Option 2: GitHub Actions Automated (30-40 min)
```bash
git add .
git commit -m "Deploy infrastructure"
git push origin main
# Monitor at: GitHub repo → Actions tab
```

### Option 3: Docker Local Testing (10 min)
```bash
docker-compose up
# Access at: http://localhost:8080
```

## ✅ Deployment Verification

After deployment, verify:

1. **Cloud Composer Environment**
   ```bash
   gcloud composer environments list --location=us-central1
   ```

2. **Airflow DAG**
   - Open Airflow UI
   - Verify `gcs_to_bigquery_dag` is listed

3. **BigQuery**
   ```bash
   bq ls --project_id=<project>
   ```

4. **GCS Buckets**
   ```bash
   gsutil ls -p <project>
   ```

## 🎓 Learning Path

### Beginner
1. Read [QUICKSTART.md](./QUICKSTART.md)
2. Follow [SETUP.md](./SETUP.md)
3. Run `make plan` to see infrastructure
4. Deploy and explore Airflow UI

### Intermediate
1. Study [DAG_DOCUMENTATION.md](./DAG_DOCUMENTATION.md)
2. Review [dags/gcs_to_bigquery_dag.py](./dags/gcs_to_bigquery_dag.py)
3. Modify schedule or add tasks
4. Use GitHub Actions for deployment

### Advanced
1. Customize Terraform modules
2. Implement data quality framework
3. Add monitoring and alerting
4. Scale infrastructure for production

## 🚀 Next Steps

After successful deployment:

1. ✅ Upload real data to source bucket
2. ✅ Monitor first DAG run in Airflow UI
3. ✅ Verify data in BigQuery tables
4. ✅ Set up alerts and monitoring
5. ✅ Document your customizations
6. ✅ Train your team

## 📞 Support

### Getting Help
1. **Documentation**: Review relevant `.md` files
2. **Logs**: Check `make logs` output
3. **Airflow UI**: View task logs and execution history
4. **GCP Console**: Check Cloud Composer and BigQuery status
5. **GitHub Issues**: Create an issue for bugs

### Common Commands

```bash
# Get help
make help

# Validate everything
make validate

# View outputs
make outputs

# Query results
make bq-query-main

# Monitor execution
make monitor logs

# Clean up
make clean
```

## 📝 File Reference

### Directory Structure
```
.
├── terraform/              # Infrastructure code
│   ├── main.tf            # Primary resources
│   ├── variables.tf       # Input variables
│   ├── outputs.tf         # Output values
│   ├── provider.tf        # Provider config
│   └── terraform.tfvars   # Configuration
├── dags/                  # Airflow DAGs
│   └── gcs_to_bigquery_dag.py
├── .github/workflows/     # CI/CD workflows
│   ├── deploy.yml        # Production deployment
│   └── quality.yml       # Quality checks
├── Documentation/         # This index + guides
├── Makefile             # Command shortcuts
├── requirements.txt     # Python dependencies
├── Dockerfile          # Docker image
├── docker-compose.yml  # Local Airflow setup
└── .gitignore          # Git ignore rules
```

## 🎉 You're Ready!

**Congratulations!** You now have a comprehensive GCP Composer data pipeline infrastructure. 

### Your Next Step
👉 Open [QUICKSTART.md](./QUICKSTART.md) or [SETUP.md](./SETUP.md) to get started!

---

### Questions?
- Check the relevant documentation file
- Review troubleshooting sections
- Check log files and error messages
- Contact your data engineering team

### Version
**v1.0.0** | Updated: 2025-11-19

---

**Happy data engineering!** 🎊
