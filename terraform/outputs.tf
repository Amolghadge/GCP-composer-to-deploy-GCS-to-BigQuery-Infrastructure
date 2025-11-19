output "composer_environment_name" {
  description = "Cloud Composer environment name"
  value       = google_composer_environment.gcs_to_bq.name
}

output "composer_dag_folder" {
  description = "Cloud Composer DAG folder path"
  value       = google_composer_environment.gcs_to_bq.config[0].dag_gcs_prefix
}

output "airflow_uri" {
  description = "Airflow UI URL"
  value       = google_composer_environment.gcs_to_bq.config[0].airflow_uri
}

output "gcs_source_bucket" {
  description = "Source GCS bucket name"
  value       = google_storage_bucket.source_bucket.name
}

output "gcs_archive_bucket" {
  description = "Archive GCS bucket name"
  value       = google_storage_bucket.archive_bucket.name
}

output "bigquery_dataset_id" {
  description = "BigQuery dataset ID"
  value       = google_bigquery_dataset.data_warehouse.dataset_id
}

output "bigquery_staging_table" {
  description = "BigQuery staging table ID"
  value       = google_bigquery_table.staging_table.table_id
}

output "bigquery_main_table" {
  description = "BigQuery main table ID"
  value       = google_bigquery_table.main_table.table_id
}

output "composer_service_account_email" {
  description = "Cloud Composer service account email"
  value       = google_service_account.composer_sa.email
}
