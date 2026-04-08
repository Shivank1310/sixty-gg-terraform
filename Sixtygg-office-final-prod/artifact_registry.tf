# ============================================================
# SIXTYGG — Artifact Registry
# AWS Equivalent: ecr.tf
# ============================================================

# -------------------------------------------------------
# Artifact Registry Repositories
# AWS Equivalent: aws_ecr_repository for each service
# -------------------------------------------------------
resource "google_artifact_registry_repository" "repos" {
  for_each = { for k, v in var.ecr : k => v if v.enabled }

  repository_id = each.value.repository_name
  project       = var.project_id
  location      = local.region
  format        = "DOCKER"
  description   = "Docker registry for ${each.key}"

  labels = local.default_labels

  # Cleanup policy — keep only last 8 images
  # AWS Equivalent: ECR lifecycle policy { max_image_count = 8 }
  cleanup_policies {
    id     = "keep-last-8"
    action = "KEEP"
    most_recent_versions {
      keep_count = 8
    }
  }

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state = "UNTAGGED"
      older_than = "604800s"  # 7 days
    }
  }
}

# -------------------------------------------------------
# Grant GKE nodes pull access
# AWS Equivalent: ECR pull permissions for EKS node role
# -------------------------------------------------------
resource "google_artifact_registry_repository_iam_member" "gke_node_pull" {
  for_each = { for k, v in var.ecr : k => v if v.enabled }

  project    = var.project_id
  location   = local.region
  repository = google_artifact_registry_repository.repos[each.key].name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

# -------------------------------------------------------
# Grant CI/CD push access
# AWS Equivalent: ECR push permissions for CodeBuild role
# -------------------------------------------------------
resource "google_artifact_registry_repository_iam_member" "cicd_push" {
  for_each = { for k, v in var.ecr : k => v if v.enabled }

  project    = var.project_id
  location   = local.region
  repository = google_artifact_registry_repository.repos[each.key].name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.cicd_sa.email}"
}
