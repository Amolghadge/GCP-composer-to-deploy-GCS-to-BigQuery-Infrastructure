# Architecture & Flow Diagrams

## 1. Overall System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          GCP Composer Data Pipeline                          │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐
│  GitHub Repo     │
├──────────────────┤
│ • Code           │
│ • Terraform      │
│ • DAG            │
│ • Workflows      │
└────────┬─────────┘
         │
         ↓ Git Push
┌──────────────────────────────────────────────────────────┐
│        GitHub Actions CI/CD Pipeline                     │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  1. Terraform Validation                                │
│  2. DAG Syntax Check                                    │
│  3. Code Quality Tests                                  │
│  4. Security Scanning (Trivy)                           │
│  5. Infrastructure Deployment (if main branch)          │
│  6. DAG Deployment to Cloud Composer                    │
│  7. Integration Testing                                 │
│  8. Notifications                                       │
│                                                          │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ↓ Deploy
        ┌────────────────────────────────┐
        │    Google Cloud Platform       │
        └────────┬───────────────────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
    ↓            ↓            ↓
┌─────────┐  ┌────────┐  ┌──────────┐
│  Cloud  │  │  Cloud │  │ BigQuery │
│Composer │  │Storage │  │          │
│(Airflow)│  │(GCS)   │  │(Data WH) │
└─────────┘  └────────┘  └──────────┘
    │            ↑  ↓          ↑  ↓
    │            │            │
    └────────────┴────────────┘
```

## 2. Data Pipeline Flow

```
Input Data Upload
       │
       ↓ (CSV Files)
┌──────────────────────┐
│  GCS Source Bucket   │
│  gs://project-source │
│  /data/*.csv         │
└──────────┬───────────┘
           │
           ↓ (Scheduled Daily at 2 AM UTC)
┌─────────────────────────────────────┐
│   Airflow DAG Execution             │
│  gcs_to_bigquery_dag                │
└─────────────────────────────────────┘
           │
           ├─→ Task 1: Check GCS Files
           │   └─→ Verify files exist
           │
           ├─→ Task 2: Load GCS to BigQuery
           │   └─→ Transfer CSV to staging
           │
           ├─→ Task 3: Validate Data Quality
           │   └─→ Check record counts
           │   └─→ Check NULL values
           │
           ├─→ Task 4: Merge Staging to Main
           │   └─→ INSERT validated records
           │   └─→ CLEAR staging table
           │
           ├─→ Task 5: Archive Files
           │   └─→ COPY to archive bucket
           │   └─→ DELETE from source
           │
           └─→ Task 6: Send Notification
               └─→ Log execution summary
               
Output: Production Data Ready for Analysis
```

## 3. Task Dependency Graph

```
                    ┌─ Start
                    │
                    ↓
            ┌─────────────────┐
            │  check_gcs      │
            │  _files         │
            └────────┬────────┘
                     │
                     ↓ (files found)
            ┌─────────────────┐
            │  load_gcs_to    │
            │  _bigquery      │
            └────────┬────────┘
                     │
                     ↓ (data loaded)
            ┌─────────────────┐
            │  validate_      │
            │  data_quality   │
            └────────┬────────┘
                     │
                     ↓ (validation passed/warning)
            ┌─────────────────┐
            │  merge_staging  │
            │  _to_main       │
            └────────┬────────┘
                     │
                     ↓ (merge complete)
            ┌─────────────────┐
            │  archive_       │
            │  processed_     │
            │  files          │
            └────────┬────────┘
                     │
                     ↓ (archive complete)
            ┌─────────────────┐
            │  send_          │
            │  notification   │
            └────────┬────────┘
                     │
                     ↓
            ┌─ End (always runs)
```

## 4. Infrastructure Components

```
┌─────────────────────────────────────────────────────────────┐
│              Google Cloud Platform Resources                │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ↓                     ↓                     ↓
    ┌────────────┐    ┌──────────────┐    ┌──────────────┐
    │ Cloud      │    │ Cloud        │    │ BigQuery     │
    │ Composer   │    │ Storage      │    │              │
    │            │    │ (GCS)        │    │              │
    ├────────────┤    ├──────────────┤    ├──────────────┤
    │ • Airflow  │    │ Bucket 1:    │    │ Dataset:     │
    │ • DAGs     │    │ Source       │    │ data_house   │
    │ • Workers  │    │ (input)      │    │              │
    │ • Logs     │    │              │    │ Tables:      │
    │            │    │ Bucket 2:    │    │ • staging    │
    │ Env Vars:  │    │ Archive      │    │ • main_data  │
    │ • GCS_SRC  │    │ (processed)  │    │              │
    │ • GCS_ARC  │    │              │    │ Schemas:     │
    │ • BQ_DS    │    │ Versioning:  │    │ • AUTO       │
    │ • BQ_TBL   │    │ ✓ Enabled    │    │ • APPEND     │
    └────────────┘    └──────────────┘    └──────────────┘
        │                     ↑  ↓               ↑  ↓
        │                     │                 │
        └─────────────────────┴─────────────────┘
              (Service Account with IAM)
```

## 5. GitHub Actions Workflow

```
GitHub Trigger (Push/PR)
         │
         ↓
    ┌─────────────────────────────┐
    │ Quality Workflow (On PR)    │
    ├─────────────────────────────┤
    │ • Code Quality (flake8)     │
    │ • Terraform Lint            │
    │ • Security Scan (Trivy)     │
    │ • DAG Tests                 │
    │ • Documentation Check       │
    └─────────┬───────────────────┘
              │
              ↓ (if PR to main)
    ┌─────────────────────────────┐
    │ Approve & Merge             │
    └────────────┬────────────────┘
                 │
                 ↓ (on main branch push)
    ┌─────────────────────────────┐
    │ Deploy Workflow             │
    ├─────────────────────────────┤
    │ 1. Terraform Plan           │
    │ 2. Terraform Apply          │
    │ 3. Deploy DAG               │
    │ 4. Run Tests                │
    │ 5. Send Notification        │
    └─────────────────────────────┘
              │
              ↓
    ┌─────────────────────────────┐
    │ Infrastructure Ready        │
    │ DAG Deployed                │
    │ Data Pipeline Active        │
    └─────────────────────────────┘
```

## 6. Data Schema & Transformation

```
INPUT (CSV File)
┌──────────────────────────────────┐
│ id | data | load_timestamp       │
├──────────────────────────────────┤
│ 1  | JSON | 2025-11-19T10:00:00Z │
│ 2  | JSON | 2025-11-19T10:05:00Z │
└──────────────────────────────────┘
           │
           ↓ (Task: load_gcs_to_bigquery)
           │
STAGING TABLE
┌──────────────────────────────────────────┐
│ id | data | load_timestamp | source_file│
├──────────────────────────────────────────┤
│ 1  | JSON | 2025-11-19T... | file.csv   │
│ 2  | JSON | 2025-11-19T... | file.csv   │
└──────────────────────────────────────────┘
           │
           ↓ (Task: validate_data_quality)
           │ (Validate: count, NULLs)
           │
           ↓ (Task: merge_staging_to_main)
           │
MAIN TABLE
┌────────────────────────────────────────────────────┐
│ id | data | load_timestamp | source_file | proc_at│
├────────────────────────────────────────────────────┤
│ 1  | JSON | 2025-11-19T... | file.csv    | 2025..│
│ 2  | JSON | 2025-11-19T... | file.csv    | 2025..│
└────────────────────────────────────────────────────┘
           │
           ↓ READY FOR ANALYTICS
```

## 7. Deployment Architecture

```
Local Development
┌──────────────────────────┐
│ • Python venv            │
│ • Terraform init         │
│ • Docker compose setup   │
│ • Local Airflow UI       │
└────────┬─────────────────┘
         │ git push
         ↓
GitHub Repository
┌──────────────────────────┐
│ • terraform/             │
│ • dags/                  │
│ • .github/workflows/     │
│ • Documentation          │
└────────┬─────────────────┘
         │ GitHub Actions Trigger
         ↓
CI/CD Pipeline
┌──────────────────────────────────┐
│ Validation & Testing             │
│ • Lint & format check            │
│ • Security scanning              │
│ • Unit tests                     │
└────────┬─────────────────────────┘
         │ if main branch & tests pass
         ↓
Production Deployment
┌──────────────────────────────────┐
│ • terraform apply                │
│ • Deploy DAG to Composer         │
│ • Run integration tests          │
│ • Send notifications             │
└────────┬─────────────────────────┘
         │
         ↓
GCP Cloud Composer
┌──────────────────────────┐
│ ✅ Infrastructure Ready  │
│ ✅ DAG Deployed          │
│ ✅ Scheduler Running     │
│ ✅ Monitoring Active     │
└──────────────────────────┘
```

## 8. Monitoring & Alerting Flow

```
DAG Execution
         │
         ├─→ Task Succeeds
         │        └─→ Log success
         │
         ├─→ Task Fails
         │        └─→ Retry (up to 2 times)
         │        └─→ If all fail: Alert
         │
         ├─→ Airflow UI
         │        ├─→ Tree view
         │        ├─→ Grid view
         │        ├─→ Logs
         │        └─→ Gantt chart
         │
         ├─→ Cloud Logging
         │        ├─→ Application logs
         │        ├─→ Infrastructure logs
         │        └─→ Audit logs
         │
         └─→ Notifications (Optional)
                  ├─→ Slack message
                  ├─→ Email alert
                  └─→ Cloud Monitoring
```

## 9. Disaster Recovery & Backup

```
Data Backup Strategy
         │
         ├─→ BigQuery
         │   ├─→ Staging table (auto-clear after merge)
         │   ├─→ Main table (versioning via timestamp)
         │   └─→ Snapshots (create as needed)
         │
         ├─→ GCS Archive Bucket
         │   ├─→ Processed files stored
         │   ├─→ Versioning enabled
         │   └─→ Lifecycle policies for retention
         │
         ├─→ Terraform State
         │   ├─→ Local or remote backend
         │   └─→ Lock to prevent concurrent changes
         │
         └─→ GitHub Repository
             ├─→ Complete infrastructure code
             ├─→ DAG code with history
             ├─→ Workflow definitions
             └─→ Documentation (version controlled)
```

## 10. Security Architecture

```
┌─────────────────────────────────────────────────────┐
│           Security Layers                           │
└─────────────────────────────────────────────────────┘
         │
         ├─→ Authentication
         │   ├─→ Service Account (GCP)
         │   ├─→ GitHub Secrets
         │   └─→ API Keys
         │
         ├─→ Authorization (IAM)
         │   ├─→ Cloud Composer Worker
         │   ├─→ BigQuery Admin
         │   ├─→ Storage Admin
         │   └─→ Service Account User
         │
         ├─→ Encryption
         │   ├─→ In Transit (HTTPS/TLS)
         │   ├─→ At Rest (GCP default)
         │   └─→ BigQuery encryption
         │
         ├─→ Network
         │   ├─→ VPC (optional)
         │   ├─→ Firewall rules (optional)
         │   └─→ Private endpoints (optional)
         │
         ├─→ Access Control
         │   ├─→ Service accounts
         │   ├─→ Resource policies
         │   └─→ Audit logging
         │
         ├─→ Code Security
         │   ├─→ Code review (PR required)
         │   ├─→ Secret scanning
         │   ├─→ Dependency scanning
         │   └─→ Static analysis
         │
         └─→ Compliance
             ├─→ Audit logs enabled
             ├─→ Data retention policies
             ├─→ Access logs
             └─→ Compliance reporting
```

---

## Legend

```
─     Horizontal flow
│     Vertical flow
↓     Downward direction
→     Arrow direction
┌─┐   Rectangular box
└─┘   Box corners
├─┤   T-junction
┼     Cross junction
✓     Checkmark / Success
✗     Cross / Failure
*     Important item
!     Warning
```

---

## File Relationships

```
Repository Root
│
├── terraform/          ─→ Creates GCP Resources
│   └── outputs.tf      ─→ Provides values for .github/workflows/
│
├── dags/               ─→ Executed by Cloud Composer
│   └── Uses env vars set by terraform/
│
├── .github/workflows/  ─→ Orchestrates deployment
│   ├── Deploys terraform/
│   ├── Uploads dags/
│   └── Runs tests
│
└── Documentation/      ─→ Guides for above components
```

---

**These diagrams provide a visual understanding of the complete system architecture and data flow.**
