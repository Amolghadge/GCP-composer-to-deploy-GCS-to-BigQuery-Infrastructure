# Airflow DAG Documentation

## Overview

The `gcs_to_bigquery_dag` is an Apache Airflow DAG that orchestrates data movement from Google Cloud Storage (GCS) to BigQuery with built-in validation and archival.

## DAG Specifications

| Property | Value |
|----------|-------|
| DAG ID | `gcs_to_bigquery_dag` |
| Schedule | Daily at 2 AM UTC (0 2 * * *) |
| Default Retries | 2 |
| Retry Delay | 5 minutes |
| Max Active Runs | 1 |
| Owner | data-engineering |

## Task Breakdown

### Task 1: check_gcs_files
**Purpose:** Verify data files exist in GCS source bucket

**Operator:** `PythonOperator`

**Functionality:**
- Lists all files in `gs://{bucket}/data/` directory
- Filters for CSV and JSON files
- Stores file list in XCom for downstream tasks
- Returns empty list if no files found

**Outputs:**
- XCom Key: `gcs_files` - List of file paths
- Log: Number of files found

**Failure Handling:**
- Retries 2 times with 5-minute delay
- Logs error and raises exception

---

### Task 2: load_gcs_to_bigquery
**Purpose:** Transfer data from GCS to BigQuery staging table

**Operator:** `GCSToBigQueryOperator`

**Configuration:**
- Source: `gs://{bucket}/data/*.csv`
- Destination: `{project}.data_warehouse.staging_data`
- Schema Detection: Auto-detect
- Write Disposition: APPEND
- Skip Leading Rows: 1
- Create Table: If needed
- Allow Jagged Rows: False
- Allow Quoted Newlines: True

**Features:**
- Automatically creates table if it doesn't exist
- Allows schema updates with `ALLOW_FIELD_ADDITION`
- Handles CSV with quoted fields
- Appends new data to existing records

**Failure Handling:**
- Inherits retry policy from DAG
- Will not overwrite existing data (APPEND mode)

---

### Task 3: validate_data_quality
**Purpose:** Validate data quality in staging table

**Operator:** `PythonOperator`

**Validations Performed:**
1. **Record Count Check**
   - Counts total records in staging table
   - Logs warning if count is 0
   
2. **NULL ID Check**
   - Counts records with null IDs
   - Returns warning if any NULL values found
   - Invalid records are skipped in merge

**Outputs:**
- XCom Key: `validation_status` - 'passed' or 'warning'
- Returns: Dictionary with validation results
- Logged: Record counts and validation status

**Failure Criteria:**
- Only fails on connection errors, not on validation warnings

---

### Task 4: merge_staging_to_main
**Purpose:** Move validated data from staging to production table

**Operator:** `PythonOperator`

**Operations:**
1. **Insert Valid Records**
   - Selects records where ID is NOT NULL
   - Adds current timestamp as `processed_at`
   - Inserts into main table

2. **Clear Staging Table**
   - Deletes all records from staging table
   - Prepares for next run

**Query:**
```sql
INSERT INTO {project}.data_warehouse.main_data 
(id, data, load_timestamp, source_file, processed_at)
SELECT 
    id,
    data,
    load_timestamp,
    source_file,
    CURRENT_TIMESTAMP() as processed_at
FROM {project}.data_warehouse.staging_data
WHERE id IS NOT NULL
```

**Safety Features:**
- Uses explicit column list
- Validates NOT NULL condition
- Includes timestamp for audit trail

---

### Task 5: archive_processed_files
**Purpose:** Archive processed files to archive bucket

**Operator:** `PythonOperator`

**Operations:**
1. **Copy to Archive**
   - Copies each processed file to archive bucket
   - Maintains original file path structure
   
2. **Delete from Source**
   - Removes file from source bucket after archival
   - Prevents reprocessing

**File Selection:** Only processes `.csv` and `.json` files

**Error Handling:**
- Logs warnings for individual file errors
- Continues processing remaining files
- Overall task succeeds if any files were archived

---

### Task 6: send_notification
**Purpose:** Send execution summary notification

**Operator:** `PythonOperator`

**Trigger Rule:** `all_done` (runs even if previous tasks fail)

**Information Included:**
- DAG ID and execution date
- Overall DAG run status
- Validation status from upstream tasks
- Current timestamp

**Output:** Logged notification message

---

## Task Dependencies

```
check_gcs_files 
    ↓
load_gcs_to_bigquery 
    ↓
validate_data_quality 
    ↓
merge_staging_to_main 
    ↓
archive_processed_files 
    ↓
send_notification
```

## Environment Variables

The following environment variables are injected by Cloud Composer:

| Variable | Purpose | Example |
|----------|---------|---------|
| `GCP_PROJECT_ID` | GCP Project ID | `my-project-123` |
| `GCS_SOURCE_BUCKET` | Source bucket name | `my-project-123-source` |
| `GCS_ARCHIVE_BUCKET` | Archive bucket name | `my-project-123-archive` |
| `BQ_DATASET_ID` | BigQuery dataset | `data_warehouse` |
| `BQ_STAGING_TABLE` | Staging table | `staging_data` |
| `BQ_MAIN_TABLE` | Production table | `main_data` |

## Data Schema

### Staging Table (`staging_data`)
```sql
id                  STRING       NULLABLE
data                JSON         NULLABLE
load_timestamp      TIMESTAMP    NULLABLE
source_file         STRING       NULLABLE
```

### Main Table (`main_data`)
```sql
id                  STRING       REQUIRED
data                JSON         NULLABLE
load_timestamp      TIMESTAMP    REQUIRED
source_file         STRING       NULLABLE
processed_at        TIMESTAMP    NULLABLE
```

## Expected Data Format

### Input CSV Format
```csv
id,data,load_timestamp
1,"{""name"":""John""}",2025-11-19T10:00:00Z
2,"{""name"":""Jane""}",2025-11-19T10:05:00Z
```

- **id**: Unique identifier (required for main table)
- **data**: JSON string representation
- **load_timestamp**: ISO format timestamp

## Monitoring and Troubleshooting

### Viewing Logs
1. Go to Airflow UI → DAG → Task
2. Click "Logs" to see task execution details
3. Check Cloud Composer logs for infrastructure issues

### Common Issues

#### No files found
- **Cause:** Files not in correct bucket/path
- **Fix:** Verify files exist in `gs://bucket/data/`
- **Check:** `gsutil ls gs://bucket/data/`

#### NULL ID validation warning
- **Cause:** Records without ID values
- **Impact:** These records are skipped during merge
- **Action:** Check source data quality

#### Staging table not clearing
- **Cause:** No valid records (all IDs NULL)
- **Impact:** Records remain in staging
- **Action:** Review data quality checks

#### Files not archiving
- **Cause:** Permission issues or wrong bucket
- **Fix:** Verify service account has Storage Admin role

## Performance Tuning

### Optimize for Large Datasets

1. **Increase Airflow Worker Capacity**
   - Update `machine_type` in Terraform (e.g., `n1-standard-8`)
   - Increase `node_count`

2. **Batch Processing**
   - Split large files before upload
   - Reduce `autodetect` if schema is known
   - Use more specific file patterns

3. **BigQuery Optimization**
   - Partition table by date for faster queries
   - Cluster by frequently filtered columns
   - Use appropriate data types

### Example: Partitioned Main Table
```sql
ALTER TABLE main_data
  ADD PARTITION EXPIRATION
  OPTIONS (partition_expiration_days=7);
```

## Scheduling Customization

To change the schedule, modify the DAG:

```python
# Current: Daily at 2 AM UTC
schedule_interval="0 2 * * *"

# Examples:
schedule_interval="0 0 * * *"      # Daily at midnight
schedule_interval="0 2 * * 1-5"    # Weekdays at 2 AM
schedule_interval="0 */3 * * *"    # Every 3 hours
```

## Alerting and Notifications

### Setup Email Alerts
Configure in Airflow UI or DAG:

```python
default_args = {
    "email": ["data-team@company.com"],
    "email_on_failure": True,
    "email_on_retry": False,
}
```

### Setup Slack Integration
Add to `software_config.pypi_packages` in Terraform:

```hcl
"apache-airflow-providers-slack" = ">=7.0.0"
```

Then update DAG to use `SlackNotificationOperator`.

## Testing the DAG

### Local Syntax Check
```bash
python -m py_compile dags/gcs_to_bigquery_dag.py
```

### Local DAG Parsing
```bash
export AIRFLOW_HOME=$(pwd)
export AIRFLOW__CORE__DAGS_FOLDER=$(pwd)/dags
python dags/gcs_to_bigquery_dag.py
```

### Test Task
```bash
airflow tasks test gcs_to_bigquery_dag check_gcs_files 2025-11-19
```

## Best Practices

1. **Data Quality**
   - Always validate source data before processing
   - Log validation metrics for audit trails
   - Use data profiling tools

2. **Error Handling**
   - Set appropriate retry counts
   - Use meaningful error messages
   - Implement graceful degradation

3. **Monitoring**
   - Set up alerts for task failures
   - Monitor execution times
   - Track data volumes and costs

4. **Security**
   - Use service accounts for authentication
   - Encrypt data in transit and at rest
   - Limit IAM permissions to minimum required

5. **Performance**
   - Monitor task execution times
   - Optimize BigQuery queries
   - Use caching where appropriate

## Maintenance

### Regular Tasks
- Weekly: Review execution logs
- Monthly: Monitor resource usage
- Quarterly: Optimize DAG performance

### Updating the DAG
1. Make changes locally
2. Test thoroughly
3. Create pull request
4. Deploy via GitHub Actions

### Backup Strategy
- BigQuery tables auto-backup to Archive dataset
- GCS files retained in archive bucket for 90 days
- Terraform state backed up to GCS
