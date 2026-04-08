# ============================================================
# SIXTYGG — Cloud Build
# AWS Equivalent: codebuild.tf
# Creates: Build projects for each service + DB migrations + Rollout deploy
# ============================================================

# -------------------------------------------------------
# Cloud Build Service Account
# AWS Equivalent: CodeBuild IAM Role (default_permissions_enabled = true)
# -------------------------------------------------------
resource "google_service_account" "cloudbuild_sa" {
  account_id   = "${local.prefix}cloudbuild-sa"
  display_name = "Cloud Build Service Account"
  description  = "AWS Equivalent: CodeBuild default IAM role"
  project      = var.project_id
}

resource "google_project_iam_member" "cloudbuild_artifact_push" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "cloudbuild_storage_access" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "cloudbuild_secret_access" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "cloudbuild_gke_access" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "cloudbuild_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

# -------------------------------------------------------
# Cloud Build Triggers — One per service
# AWS Equivalent: module "build" { for_each = var.build }
# source_type = "CODEPIPELINE" → webhook_config (triggered by pipeline)
# -------------------------------------------------------
resource "google_cloudbuild_trigger" "build_triggers" {
  for_each = { for k, v in var.build : k => v if v.enabled == true }

  name        = each.key
  project     = var.project_id
  description = "AWS Equivalent: CodeBuild project — ${each.key}"
  location    = local.region

  # AWS Equivalent: source_type = "CODEPIPELINE"
  webhook_config {
    secret = google_secret_manager_secret_version.cloudbuild_webhook_secret.id
  }

  build {
    # AWS Equivalent: build_timeout = 60 (minutes)
    timeout = "${each.value.build_timeout}s"

    # AWS Equivalent: buildspec = templatefile("${path.module}/${each.value.buildspec}", {})
    # GCP equivalent: uses build steps instead of buildspec YAML file
    step {
      name = "gcr.io/cloud-builders/docker"
      id   = "build"
      args = [
        "build",
        "-t", "${local.region}-docker.pkg.dev/${var.project_id}/${each.value.image_repo_name}:${each.value.image_tag}",
        "-t", "${local.region}-docker.pkg.dev/${var.project_id}/${each.value.image_repo_name}:$COMMIT_SHA",
        "."
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      id   = "push"
      args = [
        "push",
        "--all-tags",
        "${local.region}-docker.pkg.dev/${var.project_id}/${each.value.image_repo_name}"
      ]
    }

    # AWS Equivalent: environment_variables (PARAMETER_STORE type)
    # GCP: Secret Manager se environment variables
    available_secrets {
      secret_manager {
        version_name = "projects/${var.project_id}/secrets/${local.prefix}env-user-backend/versions/latest"
        env          = "ENV_USER_BACKEND"
      }
      secret_manager {
        version_name = "projects/${var.project_id}/secrets/${local.prefix}env-admin-backend/versions/latest"
        env          = "ENV_ADMIN_BACKEND"
      }
      secret_manager {
        version_name = "projects/${var.project_id}/secrets/${local.prefix}env-admin-frontend/versions/latest"
        env          = "ENV_ADMIN_FRONTEND"
      }
      secret_manager {
        version_name = "projects/${var.project_id}/secrets/${local.prefix}env-user-frontend/versions/latest"
        env          = "ENV_USER_FRONTEND"
      }
      secret_manager {
        version_name = "projects/${var.project_id}/secrets/${local.prefix}env-job-scheduler/versions/latest"
        env          = "ENV_JOB_SCHEDULER"
      }
    }

    images = [
      "${local.region}-docker.pkg.dev/${var.project_id}/${each.value.image_repo_name}:${each.value.image_tag}"
    ]

    options {
      # AWS Equivalent: build_compute_type = "BUILD_GENERAL1_MEDIUM"
      machine_type = "E2_HIGHCPU_8"
      logging      = "CLOUD_LOGGING_ONLY"
    }
  }

  service_account = google_service_account.cloudbuild_sa.id
  depends_on      = [google_service_account.cloudbuild_sa]
}

# -------------------------------------------------------
# DB Migrations Build
# AWS Equivalent: module "db_migrations" in codebuild.tf
# Same: npm run migrate + npm run seed
# Same: DB_PORT, DB_USER, DB_PASSWORD, DB_NAME, DB_READ_HOST, DB_WRITE_HOST from secrets
# Same: vpc_config with private subnets + node security group
# -------------------------------------------------------
resource "google_cloudbuild_trigger" "db_migrations" {
  name        = "db-migrations-${var.environment}"
  project     = var.project_id
  description = "AWS Equivalent: module db_migrations — runs npm run migrate + seed"
  location    = local.region

  webhook_config {
    secret = google_secret_manager_secret_version.cloudbuild_webhook_secret.id
  }

  build {
    timeout = "3600s"

    # AWS Equivalent: build_image = "${aws_account_id}.dkr.ecr.us-east-1.amazonaws.com/${account_name}-${environment}-admin-backend:latest"
    step {
      name = "${local.region}-docker.pkg.dev/${var.project_id}/${local.prefix}admin-backend:latest"
      id   = "db-migrate"

      # AWS Equivalent: buildspec phases.build commands (apk add jq + npm run migrate + npm run seed)
      args = ["sh", "-c", "cd /home/node/app && npm run migrate && npm run seed"]

      # AWS Equivalent: environment_variables DB_PORT, DB_USER etc from PARAMETER_STORE "/aurora/db-${environment}"
      secret_env = ["DB_PORT", "DB_USER", "DB_PASSWORD", "DB_NAME", "DB_READ_HOST", "DB_WRITE_HOST"]
    }

    # AWS Equivalent: extra_permissions ECR batch get image
    available_secrets {
      secret_manager {
        version_name = "projects/${var.project_id}/secrets/${local.prefix}db-credentials/versions/latest"
        env          = "DB_PASSWORD"
      }
    }

    options {
      # AWS Equivalent: build_compute_type = "BUILD_GENERAL1_SMALL"
      machine_type = "E2_STANDARD_2"
      logging      = "CLOUD_LOGGING_ONLY"
    }
  }

  service_account = google_service_account.cloudbuild_sa.id
}

# -------------------------------------------------------
# Rollout Deploy Build
# AWS Equivalent: module "rollout-deploy" in codebuild.tf
# Same: kubectl rollout restart deployment/$DEPLOYMENT_NAME
# Same env vars: REGION, CLUSTER_NAME, DEPLOYMENT_NAME
# Same extra_permissions: eks:DescribeCluster, eks:UpdateKubeconfig etc
# -------------------------------------------------------
resource "google_cloudbuild_trigger" "rollout_deploy" {
  name        = "rollout-deploy-${var.environment}"
  project     = var.project_id
  description = "AWS Equivalent: module rollout-deploy — kubectl rollout restart"
  location    = local.region

  webhook_config {
    secret = google_secret_manager_secret_version.cloudbuild_webhook_secret.id
  }

  build {
    timeout = "3600s"

    # AWS Equivalent: aws eks update-kubeconfig + kubectl rollout restart deployment/$DEPLOYMENT_NAME
    step {
      name = "gcr.io/cloud-builders/kubectl"
      id   = "rollout-restart"
      args = [
        "rollout", "restart",
        "deployment/$(DEPLOYMENT_NAME)"
      ]
      env = [
        # AWS Equivalent: REGION = "us-east-1"
        "CLOUDSDK_COMPUTE_REGION=${local.region}",
        # AWS Equivalent: CLUSTER_NAME = "${account_name}-${environment}"
        "CLOUDSDK_CONTAINER_CLUSTER=${local.cluster_name}",
        # AWS Equivalent: DEPLOYMENT_NAME = "user-backend-app"
        "DEPLOYMENT_NAME=${var.rollout_deployment_name}",
      ]
    }

    options {
      # AWS Equivalent: build_compute_type = "BUILD_GENERAL1_SMALL"
      machine_type = "E2_STANDARD_2"
      logging      = "CLOUD_LOGGING_ONLY"
    }
  }

  service_account = google_service_account.cloudbuild_sa.id
}

# -------------------------------------------------------
# Webhook Secret for Cloud Build Triggers
# AWS Equivalent: CodeStar connection webhook secret
# -------------------------------------------------------
resource "google_secret_manager_secret" "cloudbuild_webhook" {
  secret_id = "${local.prefix}cloudbuild-webhook"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "random_password" "cloudbuild_webhook_secret" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret_version" "cloudbuild_webhook_secret" {
  secret      = google_secret_manager_secret.cloudbuild_webhook.id
  secret_data = random_password.cloudbuild_webhook_secret.result
}

# -------------------------------------------------------
# DB Migrations Build — GAMIFICATION
# AWS Equivalent: module "db_migrations-gamification" in codebuild.tf
# Same: npm run migrate + npm run seed for gamification DB
# Same: DB_PORT, DB_USER, DB_PASSWORD, DB_NAME, DB_READ_HOST, DB_WRITE_HOST
#       from PARAMETER_STORE "/aurora/db-${env}-gamification"
# ACTIVE in AWS codebuild.tf (not commented)
# -------------------------------------------------------
resource "google_cloudbuild_trigger" "db_migrations_gamification" {
  name        = "db-migrations-${var.environment}-gamification"
  project     = var.project_id
  description = "AWS Equivalent: module db_migrations-gamification — runs npm run migrate + seed for gamification DB"
  location    = local.region

  webhook_config {
    secret = google_secret_manager_secret_version.cloudbuild_webhook_secret.id
  }

  build {
    timeout = "3600s"

    # AWS Equivalent: build_image = "${aws_account_id}.dkr.ecr.us-east-1.amazonaws.com/${account_name}-${environment}-gamification:latest"
    step {
      name = "${local.region}-docker.pkg.dev/${var.project_id}/${local.prefix}gamification:latest"
      id   = "db-migrate-gamification"

      # AWS Equivalent: buildspec phases.build commands (npm run migrate + npm run seed)
      args = ["sh", "-c", "cd /home/node/app && npm run migrate && npm run seed"]

      # AWS Equivalent: environment_variables DB_PORT, DB_USER etc from
      #                 PARAMETER_STORE "/aurora/db-${account_name}-${environment}-gamification"
      secret_env = ["DB_PORT", "DB_USER", "DB_PASSWORD", "DB_NAME", "DB_READ_HOST", "DB_WRITE_HOST"]
    }

    available_secrets {
      secret_manager {
        version_name = "projects/${var.project_id}/secrets/${local.prefix}db-credentials-gamification/versions/latest"
        env          = "DB_PASSWORD"
      }
    }

    options {
      # AWS Equivalent: build_compute_type = "BUILD_GENERAL1_SMALL"
      machine_type = "E2_STANDARD_2"
      logging      = "CLOUD_LOGGING_ONLY"
    }
  }

  service_account = google_service_account.cloudbuild_sa.id
}
