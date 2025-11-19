"""
GCS to BigQuery Data Pipeline DAG

This DAG orchestrates the movement of data from Google Cloud Storage (GCS)
to BigQuery with data validation and archival.

Author: Data Engineering Team
Created: 2025-11-19
"""

from datetime import datetime, timedelta
from typing import Dict, Any
import json
import logging

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.operators.gcs import GCSListObjectsOperator
from airflow.providers.google.cloud.transfers.gcs_to_bigquery import GCSToBigQueryOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryCreateEmptyTableOperator
from airflow.providers.google.cloud.operators.gcs import GCSDeleteObjectsOperator
from airflow.utils.dates import days_ago
import os

# Get configuration from environment variables
GCP_PROJECT_ID = os.environ.get("GCP_PROJECT_ID", "your-project-id")
GCS_SOURCE_BUCKET = os.environ.get("GCS_SOURCE_BUCKET", "source-bucket")
GCS_ARCHIVE_BUCKET = os.environ.get("GCS_ARCHIVE_BUCKET", "archive-bucket")
BQ_DATASET_ID = os.environ.get("BQ_DATASET_ID", "data_warehouse")
BQ_STAGING_TABLE = os.environ.get("BQ_STAGING_TABLE", "staging_data")
BQ_MAIN_TABLE = os.environ.get("BQ_MAIN_TABLE", "main_data")

# Configure logging
logger = logging.getLogger(__name__)

# Default arguments for DAG
default_args = {
    "owner": "data-engineering",
    "depends_on_past": False,
    "start_date": days_ago(1),
    "email": ["airflow@example.com"],
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

# DAG definition
dag = DAG(
    dag_id="gcs_to_bigquery_dag",
    default_args=default_args,
    description="Move data from GCS to BigQuery with validation and archival",
    schedule_interval="0 2 * * *",  # Daily at 2 AM UTC
    catchup=False,
    tags=["data-pipeline", "gcs", "bigquery"],
    max_active_runs=1,
)


def check_gcs_files(**context):
    """
    Check if files exist in GCS source bucket.
    
    Args:
        context: Airflow context dictionary
        
    Returns:
        List of file paths if files exist, empty list otherwise
    """
    try:
        from google.cloud import storage
        
        logger.info(f"Checking for files in {GCS_SOURCE_BUCKET}")
        client = storage.Client(project=GCP_PROJECT_ID)
        bucket = client.bucket(GCS_SOURCE_BUCKET)
        
        # List all objects in the bucket
        blobs = list(bucket.list_blobs(prefix="data/"))
        
        if not blobs:
            logger.warning(f"No files found in gs://{GCS_SOURCE_BUCKET}/data/")
            return []
        
        file_list = [blob.name for blob in blobs if blob.name.endswith(".csv") or blob.name.endswith(".json")]
        logger.info(f"Found {len(file_list)} files to process: {file_list}")
        
        # Store file list in XCom for downstream tasks
        context["task_instance"].xcom_push(key="gcs_files", value=file_list)
        
        return file_list
        
    except Exception as e:
        logger.error(f"Error checking GCS files: {str(e)}")
        raise


def validate_data(**context):
    """
    Validate data in the staging table.
    
    Args:
        context: Airflow context dictionary
        
    Returns:
        Dictionary with validation results
    """
    try:
        from google.cloud import bigquery
        
        logger.info(f"Validating data in {BQ_DATASET_ID}.{BQ_STAGING_TABLE}")
        client = bigquery.Client(project=GCP_PROJECT_ID)
        
        # Count records in staging table
        query = f"""
            SELECT COUNT(*) as record_count
            FROM `{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_STAGING_TABLE}`
        """
        
        results = client.query(query).result()
        record_count = list(results)[0].record_count
        
        logger.info(f"Staging table contains {record_count} records")
        
        if record_count == 0:
            logger.warning("No records found in staging table")
            return {"status": "warning", "record_count": 0}
        
        # Additional validation: check for null IDs
        null_query = f"""
            SELECT COUNT(*) as null_count
            FROM `{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_STAGING_TABLE}`
            WHERE id IS NULL
        """
        
        null_results = client.query(null_query).result()
        null_count = list(null_results)[0].null_count
        
        if null_count > 0:
            logger.warning(f"Found {null_count} records with null IDs")
            return {"status": "warning", "record_count": record_count, "null_count": null_count}
        
        logger.info("Data validation passed")
        context["task_instance"].xcom_push(key="validation_status", value="passed")
        
        return {"status": "success", "record_count": record_count}
        
    except Exception as e:
        logger.error(f"Error validating data: {str(e)}")
        raise


def merge_staging_to_main(**context):
    """
    Merge validated data from staging table to main table.
    
    Args:
        context: Airflow context dictionary
    """
    try:
        from google.cloud import bigquery
        
        logger.info(f"Merging data from staging to main table")
        client = bigquery.Client(project=GCP_PROJECT_ID)
        
        # Merge query - inserts validated data into main table
        merge_query = f"""
            INSERT INTO `{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_MAIN_TABLE}` 
            (id, data, load_timestamp, source_file, processed_at)
            SELECT 
                id,
                data,
                load_timestamp,
                source_file,
                CURRENT_TIMESTAMP() as processed_at
            FROM `{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_STAGING_TABLE}`
            WHERE id IS NOT NULL
        """
        
        job = client.query(merge_query)
        job.result()  # Wait for job to complete
        
        logger.info(f"Successfully merged data to main table")
        
        # Clear staging table after successful merge
        clear_query = f"""
            DELETE FROM `{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_STAGING_TABLE}`
            WHERE TRUE
        """
        
        clear_job = client.query(clear_query)
        clear_job.result()
        logger.info("Cleared staging table")
        
    except Exception as e:
        logger.error(f"Error merging data: {str(e)}")
        raise


def archive_gcs_files(**context):
    """
    Archive processed GCS files to archive bucket.
    
    Args:
        context: Airflow context dictionary
    """
    try:
        from google.cloud import storage
        
        logger.info("Archiving processed GCS files")
        client = storage.Client(project=GCP_PROJECT_ID)
        
        source_bucket = client.bucket(GCS_SOURCE_BUCKET)
        archive_bucket = client.bucket(GCS_ARCHIVE_BUCKET)
        
        # Get list of processed files
        blobs = source_bucket.list_blobs(prefix="data/")
        
        for blob in blobs:
            if blob.name.endswith(".csv") or blob.name.endswith(".json"):
                try:
                    # Copy to archive bucket
                    source_bucket.copy_blob(blob, archive_bucket, new_name=blob.name)
                    logger.info(f"Copied {blob.name} to archive bucket")
                    
                    # Delete from source bucket
                    blob.delete()
                    logger.info(f"Deleted {blob.name} from source bucket")
                    
                except Exception as e:
                    logger.warning(f"Error archiving {blob.name}: {str(e)}")
        
        logger.info("Archive process completed")
        
    except Exception as e:
        logger.error(f"Error archiving files: {str(e)}")
        raise


def send_notification(**context):
    """
    Send notification about DAG execution.
    
    Args:
        context: Airflow context dictionary
    """
    execution_date = context["execution_date"]
    dag_run = context["dag_run"]
    
    # Get validation status from XCom
    validation_status = context["task_instance"].xcom_pull(
        task_ids="validate_data_quality",
        key="validation_status"
    )
    
    message = f"""
    DAG Execution Summary:
    - DAG: gcs_to_bigquery_dag
    - Execution Date: {execution_date}
    - Status: {dag_run.state}
    - Validation Status: {validation_status or 'Unknown'}
    - Timestamp: {datetime.utcnow()}
    """
    
    logger.info(message)


# Task 1: Check if GCS files exist
check_gcs_task = PythonOperator(
    task_id="check_gcs_files",
    python_callable=check_gcs_files,
    provide_context=True,
    dag=dag,
)

# Task 2: Load data from GCS to BigQuery staging table
load_to_staging_task = GCSToBigQueryOperator(
    task_id="load_gcs_to_bigquery",
    bucket=GCS_SOURCE_BUCKET,
    source_objects=["data/*.csv"],
    destination_project_dataset_table=f"{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_STAGING_TABLE}",
    skip_leading_rows=1,
    autodetect=False,
    schema_update_options=["ALLOW_FIELD_ADDITION"],
    write_disposition="WRITE_APPEND",
    allow_quoted_newlines=True,
    allow_jagged_rows=False,
    create_disposition="CREATE_IF_NEEDED",
    location="US",
    dag=dag,
)

# Task 3: Validate data quality
validate_data_task = PythonOperator(
    task_id="validate_data_quality",
    python_callable=validate_data,
    provide_context=True,
    dag=dag,
)

# Task 4: Merge staging data to main table
merge_to_main_task = PythonOperator(
    task_id="merge_staging_to_main",
    python_callable=merge_staging_to_main,
    provide_context=True,
    dag=dag,
)

# Task 5: Archive processed files
archive_files_task = PythonOperator(
    task_id="archive_processed_files",
    python_callable=archive_gcs_files,
    provide_context=True,
    dag=dag,
)

# Task 6: Send notification
notify_task = PythonOperator(
    task_id="send_notification",
    python_callable=send_notification,
    provide_context=True,
    trigger_rule="all_done",
    dag=dag,
)

# Define task dependencies
check_gcs_task >> load_to_staging_task >> validate_data_task >> merge_to_main_task >> archive_files_task >> notify_task
