# ============================================================
# SIXTYGG — Secret Manager
# AWS Equivalent: parameter.tf (SSM Parameter Store)
# ============================================================

# -------------------------------------------------------
# App Secrets
# AWS Equivalent: aws_ssm_parameter (SecureString) for each app
# /aurora/db-dev
# /app/env-user-backend-dev
# /app/env-admin-backend-dev
# /app/env-admin-frontend-dev
# /app/env-user-frontend-dev
# /app/env-job-scheduler-dev
# -------------------------------------------------------
resource "google_secret_manager_secret" "app_secrets" {
  for_each = var.app_secrets

  secret_id = each.value.secret_id
  project   = var.project_id

  labels = local.default_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "app_secrets" {
  for_each = var.app_secrets

  secret      = google_secret_manager_secret.app_secrets[each.key].id
  secret_data = each.value.value
}

# -------------------------------------------------------
# Grant GKE pods access to secrets
# AWS Equivalent: IAM policy GetParameter on SSM
# -------------------------------------------------------
resource "google_secret_manager_secret_iam_member" "gke_secret_access" {
  for_each = var.app_secrets

  secret_id = google_secret_manager_secret.app_secrets[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_storage_sa.email}"
  project   = var.project_id
}

# Grant GKE node SA access
resource "google_secret_manager_secret_iam_member" "gke_node_secret_access" {
  for_each = var.app_secrets

  secret_id = google_secret_manager_secret.app_secrets[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.gke_node_sa.email}"
  project   = var.project_id
}

# -------------------------------------------------------
# Gamification App Secrets
# AWS Equivalent: parameter.tf
#   module "parameter-store-db-gamification"     → /aurora/db-${env}-gamification
#   module "parameter-store-gamification"         → /app/env-gamification-${env}
# Both are ACTIVE (not commented) in AWS parameter.tf
# -------------------------------------------------------
resource "google_secret_manager_secret" "gamification_db_credentials" {
  secret_id = "${local.prefix}db-credentials-gamification"
  project   = var.project_id
  labels    = local.default_labels

  # AWS Equivalent: /aurora/db-${account_name}-${environment}-gamification (SecureString)
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "gamification_db_credentials" {
  secret      = google_secret_manager_secret.gamification_db_credentials.id
  secret_data = "FILL_BEFORE_APPLY"
}

resource "google_secret_manager_secret" "env_gamification" {
  secret_id = "${local.prefix}env-gamification"
  project   = var.project_id
  labels    = local.default_labels

  # AWS Equivalent: /app/env-gamification-${account_name}-${environment} (SecureString)
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "env_gamification" {
  secret      = google_secret_manager_secret.env_gamification.id
  secret_data = "FILL_BEFORE_APPLY"
}

# Grant GKE pods access to gamification secrets
# AWS Equivalent: IAM policy GetParameter on SSM for gamification params
resource "google_secret_manager_secret_iam_member" "gke_gamification_db_access" {
  secret_id = google_secret_manager_secret.gamification_db_credentials.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_storage_sa.email}"
  project   = var.project_id
}

resource "google_secret_manager_secret_iam_member" "gke_gamification_env_access" {
  secret_id = google_secret_manager_secret.env_gamification.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_storage_sa.email}"
  project   = var.project_id
}

resource "google_secret_manager_secret_iam_member" "gke_node_gamification_db_access" {
  secret_id = google_secret_manager_secret.gamification_db_credentials.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.gke_node_sa.email}"
  project   = var.project_id
}

resource "google_secret_manager_secret_iam_member" "gke_node_gamification_env_access" {
  secret_id = google_secret_manager_secret.env_gamification.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.gke_node_sa.email}"
  project   = var.project_id
}
