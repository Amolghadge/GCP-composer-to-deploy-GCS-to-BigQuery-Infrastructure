# IAM Setup Guide

## Issue: "Policy update access denied" Error

If you encounter the error:
```
Error: Error applying IAM policy for project "...": Error setting IAM policy for project "...": googleapi: Error 403: Policy update access denied., forbidden
```

This means the service account used for Terraform doesn't have permission to modify IAM policies.

## Solution

### Step 1: Grant IAM Admin Role to Terraform Service Account

Run this command with an account that has Project Editor or Owner role:

```bash
# Set your project ID
PROJECT_ID="your-project-id"
TERRAFORM_SA_EMAIL="terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com"

# Grant the role
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member=serviceAccount:${TERRAFORM_SA_EMAIL} \
  --role=roles/resourcemanager.projectIamAdmin
```

### Step 2: Re-run Terraform

After granting the role, re-run the Terraform apply:

```bash
cd terraform
terraform apply -auto-approve
```

## Alternative: Manual IAM Assignment

If you prefer not to grant IAM Admin permissions to the service account, you can manually assign roles:

```bash
PROJECT_ID="your-project-id"
COMPOSER_SA_EMAIL="cloud-composer-sa@${PROJECT_ID}.iam.gserviceaccount.com"

# Assign roles
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member=serviceAccount:${COMPOSER_SA_EMAIL} \
  --role=roles/composer.worker

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member=serviceAccount:${COMPOSER_SA_EMAIL} \
  --role=roles/bigquery.admin

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member=serviceAccount:${COMPOSER_SA_EMAIL} \
  --role=roles/storage.admin
```

Then comment out the IAM resources in `main.tf` (lines 179-200).

## Required Permissions for Terraform Service Account

For full automation, the Terraform service account needs these roles:
- `roles/composer.admin` - Cloud Composer admin
- `roles/bigquery.admin` - BigQuery admin
- `roles/storage.admin` - Storage admin
- `roles/resourcemanager.projectIamAdmin` - To set IAM policies
- `roles/iam.serviceAccountAdmin` - To create/manage service accounts

## For GitHub Actions CI/CD

If using GitHub Actions with a service account key (`GCP_SA_KEY`), ensure that service account has at minimum:
- `roles/resourcemanager.projectIamAdmin` 
- `roles/composer.admin`
- `roles/bigquery.admin` 
- `roles/storage.admin`
- `roles/iam.serviceAccountAdmin`

Recommended: Use a dedicated service account for CI/CD with only these specific roles.
