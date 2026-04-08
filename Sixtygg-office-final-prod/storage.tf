# ============================================================
# SIXTYGG — Cloud Storage
# AWS Equivalent: s3.tf
# ============================================================

# -------------------------------------------------------
# Active Storage Bucket
# AWS Equivalent: active_s3 { name = "sixtygg-dev-active-storage" }
# Used for app file uploads (images, documents etc)
# -------------------------------------------------------
resource "google_storage_bucket" "active_storage" {
  name          = var.active_s3.name
  location      = local.region
  project       = var.project_id
  force_destroy = false

  uniform_bucket_level_access = true

  labels = local.default_labels

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 3
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  cors {
    origin          = ["https://*.${var.base_domain_name}"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

# -------------------------------------------------------
# Artifacts Bucket
# AWS Equivalent: artifact_s3 { name = "sixtygg-dev-artifacts" }
# Used for CI/CD build artifacts (codepipeline_bucket equivalent)
# -------------------------------------------------------
resource "google_storage_bucket" "artifacts" {
  name          = var.artifact_s3.name
  location      = local.region
  project       = var.project_id
  force_destroy = false

  uniform_bucket_level_access = true

  labels = local.default_labels

  versioning {
    enabled = true
  }

  # Delete old artifacts after 30 days
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

# NOTE: Terraform state bucket "sixtygg-terraform-state" was created
# manually via gsutil — NOT managed by Terraform to avoid conflicts
# AWS Equivalent: S3 bucket for Terraform backend (created separately)

# -------------------------------------------------------
# IAM — Give app pods access to active storage bucket
# AWS Equivalent: S3 bucket policy / IAM role for pods
# -------------------------------------------------------
resource "google_storage_bucket_iam_member" "app_active_storage_access" {
  bucket = google_storage_bucket.active_storage.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.app_storage_sa.email}"
}

resource "google_storage_bucket_iam_member" "cicd_artifacts_access" {
  bucket = google_storage_bucket.artifacts.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.cicd_sa.email}"
}

# -------------------------------------------------------
# Terraform State Bucket
# AWS Equivalent: aws_s3_bucket "tf_state" in s3.tf
# Active in AWS: bucket + versioning + encryption — ACTIVE (not commented)
# aws_s3_bucket_policy "tf_state_policy" — COMMENTED OUT in AWS (so commented here too)
# -------------------------------------------------------
resource "google_storage_bucket" "tf_state" {
  name          = var.tfstate_s3.name
  location      = local.region
  project       = var.project_id
  force_destroy = false

  # AWS Equivalent: prevent_destroy = true lifecycle rule
  lifecycle {
    prevent_destroy = true
  }

  # AWS Equivalent: aws_s3_bucket_versioning { status = "Enabled" }
  versioning {
    enabled = true
  }

  # AWS Equivalent: aws_s3_bucket_server_side_encryption_configuration { sse_algorithm = "AES256" }
  encryption {
    default_kms_key_name = ""
  }

  uniform_bucket_level_access = true

  labels = local.default_labels
}

# NOTE: Bucket IAM policy is COMMENTED OUT below
# AWS Equivalent: aws_s3_bucket_policy "tf_state_policy" — also COMMENTED OUT in AWS s3.tf
# Uncomment and apply AFTER first successful terraform apply (same as AWS)

# resource "google_storage_bucket_iam_member" "tf_state_policy" {
#   bucket = google_storage_bucket.tf_state.name
#   role   = "roles/storage.admin"
#   member = "serviceAccount:FILL_YOUR_TERRAFORM_SA@PROJECT_ID.iam.gserviceaccount.com"
# }
