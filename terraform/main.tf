# GCS Buckets for data movement
resource "google_storage_bucket" "source_bucket" {
  name          = "${var.project_id}-source"
  project       = var.project_id
  location      = var.region
  force_destroy = false

  versioning {
    enabled = true
  }

  labels = var.environment_labels
}

resource "google_storage_bucket" "archive_bucket" {
  name          = "${var.project_id}-archive"
  project       = var.project_id
  location      = var.region
  force_destroy = false

  versioning {
    enabled = true
  }

  labels = var.environment_labels
}

# BigQuery Dataset
resource "google_bigquery_dataset" "data_warehouse" {
  dataset_id    = var.bigquery_dataset
  project       = var.project_id
  location      = var.region
  friendly_name = "Data Warehouse"
  description   = "Main data warehouse for processed data"

  labels = var.environment_labels
}

# BigQuery Staging Table
resource "google_bigquery_table" "staging_table" {
  dataset_id = google_bigquery_dataset.data_warehouse.dataset_id
  table_id   = var.bigquery_staging_table
  project    = var.project_id

  schema = jsonencode([
    {
      name        = "id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Record ID"
    },
    {
      name        = "data"
      type        = "JSON"
      mode        = "NULLABLE"
      description = "Data payload"
    },
    {
      name        = "load_timestamp"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "When the record was loaded"
    },
    {
      name        = "source_file"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Source GCS file path"
    }
  ])

  labels = var.environment_labels
}

# BigQuery Main Table
resource "google_bigquery_table" "main_table" {
  dataset_id = google_bigquery_dataset.data_warehouse.dataset_id
  table_id   = var.bigquery_main_table
  project    = var.project_id

  schema = jsonencode([
    {
      name        = "id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Record ID"
    },
    {
      name        = "data"
      type        = "JSON"
      mode        = "NULLABLE"
      description = "Data payload"
    },
    {
      name        = "load_timestamp"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "When the record was loaded"
    },
    {
      name        = "source_file"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Source GCS file path"
    },
    {
      name        = "processed_at"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "When the record was processed"
    }
  ])

  labels = var.environment_labels
}

# Cloud Composer Environment
resource "google_composer_environment" "gcs_to_bq" {
  name    = var.composer_env_name
  project = var.project_id
  region  = var.region

  config {
    node_count = var.node_count

    node_config {
      zone         = "${var.region}-a"
      machine_type = var.machine_type
      disk_size_gb = 30

      service_account = google_service_account.composer_sa.email

      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform",
      ]
    }

    software_config {
      airflow_config_overrides = {
        "core-load_examples"         = "False"
        "logging-logging_level"      = "INFO"
        "webserver-expose_config"    = "True"
      }

      pypi_packages = {
        apache-airflow-providers-google = ">=10.0.0"
        pandas                          = ">=1.3.0"
        python-dateutil                 = ">=2.8.0"
      }

      env_variables = {
        GCS_SOURCE_BUCKET    = google_storage_bucket.source_bucket.name
        GCS_ARCHIVE_BUCKET   = google_storage_bucket.archive_bucket.name
        BQ_DATASET_ID        = google_bigquery_dataset.data_warehouse.dataset_id
        BQ_STAGING_TABLE     = google_bigquery_table.staging_table.table_id
        BQ_MAIN_TABLE        = google_bigquery_table.main_table.table_id
        GCP_PROJECT_ID       = var.project_id
      }
    }
  }

  labels = var.environment_labels

  depends_on = [
    google_project_iam_member.composer_worker,
    google_project_iam_member.composer_bq_admin,
    google_project_iam_member.composer_storage_admin,
  ]
}

# Service Account for Cloud Composer
resource "google_service_account" "composer_sa" {
  account_id   = "cloud-composer-sa"
  project      = var.project_id
  display_name = "Cloud Composer Service Account"
}

# IAM Roles for Cloud Composer Service Account
resource "google_project_iam_member" "composer_worker" {
  project = var.project_id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${google_service_account.composer_sa.email}"
}

resource "google_project_iam_member" "composer_bq_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.composer_sa.email}"
}

resource "google_project_iam_member" "composer_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.composer_sa.email}"
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "composer.googleapis.com",
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "storage-api.googleapis.com",
    "container.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}
