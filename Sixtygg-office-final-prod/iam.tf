# ============================================================
# SIXTYGG — IAM
# AWS Equivalent: iam.tf
# Creates: Service Accounts, IAM Bindings, Workload Identity
# ============================================================

# -------------------------------------------------------
# GKE Node Service Account
# AWS Equivalent: EKS node IAM role
# -------------------------------------------------------
resource "google_service_account" "gke_node_sa" {
  account_id   = "${local.prefix}gke-node-sa"
  display_name = "GKE Node Service Account"
  description  = "Service account for GKE nodes"
  project      = var.project_id
}

# Grant required permissions to GKE nodes
resource "google_project_iam_member" "gke_node_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

resource "google_project_iam_member" "gke_node_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

resource "google_project_iam_member" "gke_node_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

resource "google_project_iam_member" "gke_node_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

# -------------------------------------------------------
# Bastion Service Account
# AWS Equivalent: EC2 instance profile
# -------------------------------------------------------
resource "google_service_account" "bastion_sa" {
  account_id   = "${local.prefix}bastion-sa"
  display_name = "Bastion Service Account"
  description  = "Service account for bastion server"
  project      = var.project_id
}

resource "google_project_iam_member" "bastion_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.bastion_sa.email}"
}

# -------------------------------------------------------
# CI/CD Service Account
# AWS Equivalent: CodeBuild IAM Role
# -------------------------------------------------------
resource "google_service_account" "cicd_sa" {
  account_id   = "${local.prefix}cicd-sa"
  display_name = "CI/CD Service Account"
  description  = "Service account for CI/CD pipelines to push Docker images"
  project      = var.project_id
}

resource "google_project_iam_member" "cicd_artifact_push" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cicd_sa.email}"
}

resource "google_project_iam_member" "cicd_gke_deploy" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.cicd_sa.email}"
}

# -------------------------------------------------------
# App Pod Service Account — Storage Access
# AWS Equivalent: pod_identity_association for admin-backend-app
#   roles/storage.admin (S3FullAccess equivalent)
# -------------------------------------------------------
resource "google_service_account" "app_storage_sa" {
  account_id   = "${local.prefix}app-storage-sa"
  display_name = "App Storage Service Account"
  description  = "Gives pods access to Cloud Storage (AWS: S3 access via Pod Identity)"
  project      = var.project_id
}

resource "google_project_iam_member" "app_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.app_storage_sa.email}"
}

resource "google_project_iam_member" "app_secret_access" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.app_storage_sa.email}"
}

# -------------------------------------------------------
# CloudWatch Equivalent — Monitoring Service Account
# AWS Equivalent: eks_cloudwatch pod_identity_association
# -------------------------------------------------------
resource "google_service_account" "monitoring_sa" {
  account_id   = "${local.prefix}monitoring-sa"
  display_name = "Monitoring Service Account"
  description  = "AWS Equivalent: eks_cloudwatch role for CloudWatch agent"
  project      = var.project_id
}

resource "google_project_iam_member" "monitoring_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.monitoring_sa.email}"
}

resource "google_project_iam_member" "monitoring_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.monitoring_sa.email}"
}

# -------------------------------------------------------
# Workload Identity Bindings
# AWS Equivalent: pod_identity_associations in eks { }
# Allows GKE pods to use Service Accounts
# -------------------------------------------------------
resource "google_service_account_iam_member" "workload_identity_bindings" {
  for_each = var.workload_identity

  service_account_id = google_service_account.app_storage_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.namespace}/${each.value.service_account}]"
}

# Monitoring workload identity
resource "google_service_account_iam_member" "monitoring_workload_identity" {
  service_account_id = google_service_account.monitoring_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[kube-system/cloudwatch-agent]"
}
