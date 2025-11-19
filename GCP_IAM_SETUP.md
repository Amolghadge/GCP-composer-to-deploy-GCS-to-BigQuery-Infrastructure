# GCP Authentication and IAM Setup Guide

## Problem Summary

Your Terraform deployment is failing with: "Policy update access denied" because the authenticated GCP account doesn't have permission to modify IAM policies on the project.

### Root Cause:
- Your GCP Console login: `amolai0126@gmail.com`  
- Your Terraform service account: `terraform-sa@ornate-producer-477604-s3.iam.gserviceaccount.com`
- The service account needs role: `roles/resourcemanager.projectIamAdmin`

## Solution Options

### Option 1: GCP Console (Easiest) ✅ RECOMMENDED

1. Go to: [IAM & Admin](https://console.cloud.google.com/iam-admin/iam?project=ornate-producer-477604-s3)
2. Click **"Grant Access"** button (top right)
3. New Principal: `terraform-sa@ornate-producer-477604-s3.iam.gserviceaccount.com`
4. Role: `Project IAM Admin` (type to search)
5. Click **"Save"**

### Option 2: Using gcloud CLI

First, authenticate with a service account that has permissions:

```bash
# If you have the service account key file
gcloud auth activate-service-account --key-file=~/path/to/service-account-key.json

# Set the project
gcloud config set project ornate-producer-477604-s3

# Grant the role
gcloud projects add-iam-policy-binding ornate-producer-477604-s3 \
  --member=serviceAccount:terraform-sa@ornate-producer-477604-s3.iam.gserviceaccount.com \
  --role=roles/resourcemanager.projectIamAdmin
```

### Option 3: For GitHub Actions CI/CD

Update your GitHub repository secrets:

1. Go to: GitHub repo → Settings → Secrets and variables → Actions
2. Ensure `GCP_SA_KEY` secret contains a service account key with these roles:
   - `roles/resourcemanager.projectIamAdmin`
   - `roles/composer.admin`
   - `roles/bigquery.admin`
   - `roles/storage.admin`
   - `roles/iam.serviceAccountAdmin`

## Required Service Account Permissions

Minimum roles needed:
```
roles/resourcemanager.projectIamAdmin
roles/composer.admin
roles/bigquery.admin
roles/storage.admin
roles/iam.serviceAccountAdmin
```

Or use the broader role for development:
```
roles/editor  # Not recommended for production
```

## Next Steps

1. **Immediately**: Grant permissions using Option 1 (GCP Console) or Option 2 (gcloud)
2. **Then**: Retry Terraform apply:
   ```bash
   cd terraform
   terraform apply -auto-approve
   ```
3. **Verify**: Check that resources are created in GCP Console

## Security Notes

- For production: Create a custom IAM role with minimal permissions
- For CI/CD: Use a dedicated service account (not personal account)
- Rotate service account keys regularly
- Don't commit service account keys to Git
