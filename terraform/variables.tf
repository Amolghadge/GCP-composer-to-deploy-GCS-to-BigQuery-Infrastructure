variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region for resources"
  type        = string
  default     = "us-central1"
}

variable "composer_env_name" {
  description = "Cloud Composer environment name"
  type        = string
  default     = "gcs-to-bq-composer"
}

variable "machine_type" {
  description = "Machine type for Composer nodes"
  type        = string
  default     = "n1-standard-4"
}

variable "node_count" {
  description = "Number of nodes in Composer environment"
  type        = number
  default     = 1
}

variable "python_version" {
  description = "Python version for Airflow"
  type        = string
  default     = "3"
}

variable "airflow_version" {
  description = "Apache Airflow version"
  type        = string
  default     = "2"
}

variable "gcs_source_bucket" {
  description = "GCS source bucket name"
  type        = string
}

variable "gcs_archive_bucket" {
  description = "GCS archive bucket name"
  type        = string
}

variable "bigquery_dataset" {
  description = "BigQuery dataset ID"
  type        = string
  default     = "data_warehouse"
}

variable "bigquery_staging_table" {
  description = "BigQuery staging table name"
  type        = string
  default     = "staging_data"
}

variable "bigquery_main_table" {
  description = "BigQuery main data table name"
  type        = string
  default     = "main_data"
}

variable "environment_labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default = {
    project     = "data-pipeline"
    environment = "production"
    managed_by  = "terraform"
  }
}
