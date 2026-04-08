# ============================================================
# SIXTYGG — Cloud Deploy (CI/CD Pipelines)
# AWS Equivalent: codepipeline.tf
# Flow: Source → Build → DBMigrations → DeployToGKE (Helm)
# Same as AWS: Source(CodeStar) → Build(CodeBuild) → DBMigrations → DeployToEKS(Helm)
# ============================================================

# -------------------------------------------------------
# GitHub Connection
# AWS Equivalent: aws_codestarconnections_connection "github-stag"
# provider_type = "GitHub"
# -------------------------------------------------------
resource "google_cloudbuildv2_connection" "github" {
  name     = "github-${var.environment}"
  project  = var.project_id
  location = local.region

  github_config {
    app_installation_id = var.github_app_installation_id
    authorizer_credential {
      oauth_token_secret_version = google_secret_manager_secret_version.github_token.id
    }
  }

  depends_on = [google_secret_manager_secret_version.github_token]
}

# GitHub Token Secret
# AWS Equivalent: CodeStar Connection OAuth token
resource "google_secret_manager_secret" "github_token" {
  secret_id = "${local.prefix}github-token"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "github_token" {
  secret      = google_secret_manager_secret.github_token.id
  secret_data = var.github_token
}

# -------------------------------------------------------
# GitHub Repository Links
# AWS Equivalent: FullRepositoryId in each pipeline Source stage
# -------------------------------------------------------
resource "google_cloudbuildv2_repository" "repos" {
  for_each = {
    admin-backend  = var.admin_backend_repo.fullrepositoryid
    admin-frontend = var.admin_frontend_repo.fullrepositoryid
    user-frontend  = var.user_frontend_repo.fullrepositoryid
    user-backend   = var.user_backend_repo.fullrepositoryid
    job-scheduler  = var.job_scheduler_repo.fullrepositoryid
  }

  name              = "${local.prefix}${each.key}"
  project           = var.project_id
  location          = local.region
  parent_connection = google_cloudbuildv2_connection.github.id
  remote_uri        = "https://github.com/${each.value}.git"
}

# -------------------------------------------------------
# S3 Artifact Bucket equivalent
# AWS Equivalent: aws_s3_bucket "codepipeline_bucket" + aws_s3_bucket_public_access_block
# -------------------------------------------------------
resource "google_storage_bucket" "codepipeline_bucket" {
  name          = "${local.prefix}codepipeline-artifacts"
  project       = var.project_id
  location      = local.region
  force_destroy = true

  # AWS Equivalent: block_public_acls, block_public_policy, restrict_public_buckets = true
  public_access_prevention = "enforced"

  uniform_bucket_level_access = true

  labels = local.default_labels
}

# -------------------------------------------------------
# CodePipeline IAM Role equivalent
# AWS Equivalent: aws_iam_role "codepipeline_role" + aws_iam_role_policy "codepipeline_policy"
# -------------------------------------------------------
resource "google_project_iam_member" "cloudbuild_deploy_access" {
  project = var.project_id
  role    = "roles/clouddeploy.operator"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "cloudbuild_helm_access" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

# -------------------------------------------------------
# GKE Deploy Target
# AWS Equivalent: provider = "EKS" + ClusterName in codepipeline stage
# -------------------------------------------------------
resource "google_clouddeploy_target" "gke_target" {
  name     = "${local.prefix}gke-target"
  project  = var.project_id
  location = local.region
  description = "AWS Equivalent: EKS deploy target — ClusterName = var.eks.name"

  # AWS Equivalent: ClusterName = var.eks.name
  gke {
    cluster = "projects/${var.project_id}/locations/${local.region}/clusters/${local.cluster_name}"
  }

  labels     = local.default_labels
  depends_on = [google_container_cluster.gke]
}

# -------------------------------------------------------
# Admin Backend Pipeline
# AWS Equivalent: aws_codepipeline "admin_backend"
# Stages: Source → Build → DBMigrations → DeployToEKS(Helm)
# HelmReleaseName = "admin-backend"
# HelmChartLocation = "chart"
# HelmValuesFiles = "stag-values.yaml,config-values.yaml"
# -------------------------------------------------------
resource "google_clouddeploy_delivery_pipeline" "admin_backend" {
  name        = "${local.prefix}admin-backend"
  project     = var.project_id
  location    = local.region
  description = "AWS Equivalent: aws_codepipeline admin_backend — Source→Build→DBMigrations→DeployHelm"

  labels = local.default_labels

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.gke_target.target_id
      # AWS Equivalent: HelmValuesFiles = "stag-values.yaml,config-values.yaml"
      profiles  = ["stag-values", "config-values"]
    }
  }
}

# -------------------------------------------------------
# Admin Frontend Pipeline
# AWS Equivalent: aws_codepipeline "admin_frontend"
# Stages: Source → Build → DeployToEKS(Helm)
# HelmReleaseName = "admin-frontend"
# HelmValuesFiles = "stag-values.yaml"
# -------------------------------------------------------
resource "google_clouddeploy_delivery_pipeline" "admin_frontend" {
  name        = "${local.prefix}admin-frontend"
  project     = var.project_id
  location    = local.region
  description = "AWS Equivalent: aws_codepipeline admin_frontend — Source→Build→DeployHelm"

  labels = local.default_labels

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.gke_target.target_id
      # AWS Equivalent: HelmValuesFiles = "stag-values.yaml"
      profiles  = ["stag-values"]
    }
  }
}

# -------------------------------------------------------
# User Frontend Pipeline
# AWS Equivalent: aws_codepipeline "user_frontend"
# Stages: Source → Build → DeployToEKS(Helm)
# HelmReleaseName = "user-frontend"
# HelmValuesFiles = "stag-values.yaml"
# -------------------------------------------------------
resource "google_clouddeploy_delivery_pipeline" "user_frontend" {
  name        = "${local.prefix}user-frontend"
  project     = var.project_id
  location    = local.region
  description = "AWS Equivalent: aws_codepipeline user_frontend — Source→Build→DeployHelm"

  labels = local.default_labels

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.gke_target.target_id
      # AWS Equivalent: HelmValuesFiles = "stag-values.yaml"
      profiles  = ["stag-values"]
    }
  }
}

# -------------------------------------------------------
# User Backend Pipeline
# AWS Equivalent: aws_codepipeline "user_backend"
# Stages: Source → Build → DeployToEKS(Helm) → RolloutDeployment
# HelmReleaseName = "user-backend"
# HelmValuesFiles = "stag-values.yaml,config-values.yaml"
# Extra stage: RolloutDeployment (module.rollout-deploy)
# -------------------------------------------------------
resource "google_clouddeploy_delivery_pipeline" "user_backend" {
  name        = "${local.prefix}user-backend"
  project     = var.project_id
  location    = local.region
  description = "AWS Equivalent: aws_codepipeline user_backend — Source→Build→DeployHelm→RolloutDeploy"

  labels = local.default_labels

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.gke_target.target_id
      # AWS Equivalent: HelmValuesFiles = "stag-values.yaml,config-values.yaml"
      profiles  = ["stag-values", "config-values"]
    }
  }
}

# -------------------------------------------------------
# Job Scheduler Pipeline
# AWS Equivalent: aws_codepipeline "job-scheduler"
# Stages: Source → Build → DeployToEKS(Helm) + DeployWorkerToEKS(Helm)
# HelmReleaseName = "job-scheduler" + "job-scheduler-worker"
# HelmValuesFiles = "stag-jobs-values.yaml,config-values.yaml"
#                   "stag-worker-values.yaml,config-values.yaml"
# -------------------------------------------------------
resource "google_clouddeploy_delivery_pipeline" "job_scheduler" {
  name        = "${local.prefix}job-scheduler"
  project     = var.project_id
  location    = local.region
  description = "AWS Equivalent: aws_codepipeline job-scheduler — Source→Build→DeployHelm+DeployWorkerHelm"

  labels = local.default_labels

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.gke_target.target_id
      # AWS Equivalent: HelmValuesFiles = "stag-jobs-values.yaml,config-values.yaml"
      profiles  = ["stag-jobs-values", "config-values"]
    }
  }
}

# -------------------------------------------------------
# Job Scheduler Worker Pipeline (EXTRA)
# AWS Equivalent: action "DeployWorkerToEKS" in job-scheduler pipeline
# HelmReleaseName = "job-scheduler-worker"
# HelmValuesFiles = "stag-worker-values.yaml,config-values.yaml"
# This was missing earlier — now added!
# -------------------------------------------------------
resource "google_clouddeploy_delivery_pipeline" "job_scheduler_worker" {
  name        = "${local.prefix}job-scheduler-worker"
  project     = var.project_id
  location    = local.region
  description = "AWS Equivalent: DeployWorkerToEKS action in job-scheduler pipeline"

  labels = local.default_labels

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.gke_target.target_id
      # AWS Equivalent: HelmValuesFiles = "stag-worker-values.yaml,config-values.yaml"
      profiles  = ["stag-worker-values", "config-values"]
    }
  }
}

# -------------------------------------------------------
# Pipeline Triggers — Connect GitHub → Cloud Build → Helm Deploy
# AWS Equivalent: Each aws_codepipeline Stage "Source" + Stage "Build" + Stage "DeployToEKS"
# Full flow: GitHub push → Build Docker → Push to Registry → Helm upgrade on GKE
# -------------------------------------------------------
resource "google_cloudbuild_trigger" "pipeline_triggers" {
  for_each = {
    admin-backend  = var.admin_backend_repo.fullrepositoryid
    admin-frontend = var.admin_frontend_repo.fullrepositoryid
    user-frontend  = var.user_frontend_repo.fullrepositoryid
    user-backend   = var.user_backend_repo.fullrepositoryid
    job-scheduler  = var.job_scheduler_repo.fullrepositoryid
  }

  name        = "${local.prefix}${each.key}-trigger"
  project     = var.project_id
  location    = local.region
  description = "AWS Equivalent: CodePipeline — Source+Build+DeployToEKS(Helm) — ${each.key}"

  # AWS Equivalent: BranchName = var.branch_name.name
  repository_event_config {
    repository = google_cloudbuildv2_repository.repos[each.key].id
    push {
      branch = var.branch_name.name
    }
  }

  build {
    timeout = "3600s"

    # ---
    # Stage 1: Build Docker image
    # AWS Equivalent: Stage "Build" — CodeBuild buildspec docker build
    # ---
    step {
      name = "gcr.io/cloud-builders/docker"
      id   = "build"
      args = [
        "build",
        "-t", "${local.region}-docker.pkg.dev/${var.project_id}/${local.prefix}${each.key}:$COMMIT_SHA",
        "-t", "${local.region}-docker.pkg.dev/${var.project_id}/${local.prefix}${each.key}:latest",
        "."
      ]
    }

    # Stage 2: Push to Artifact Registry
    # AWS Equivalent: CodeBuild docker push to ECR
    step {
      name = "gcr.io/cloud-builders/docker"
      id   = "push"
      args = [
        "push", "--all-tags",
        "${local.region}-docker.pkg.dev/${var.project_id}/${local.prefix}${each.key}"
      ]
    }

    # ---
    # Stage 3: Helm Deploy to GKE
    # AWS Equivalent: Stage "DeployToEKS"
    #   provider = "EKS"
    #   HelmReleaseName = each.key (e.g. "admin-backend")
    #   HelmChartLocation = "chart"
    #   HelmValuesFiles = depends on service
    # ---
    step {
      name = "alpine/helm:3.14.0"
      id   = "helm-deploy"
      args = [
        "upgrade", "--install",
        each.key,                          # HelmReleaseName
        "./chart",                          # HelmChartLocation = "chart"
        "--set", "image.tag=$COMMIT_SHA",
        "--set", "image.repository=${local.region}-docker.pkg.dev/${var.project_id}/${local.prefix}${each.key}",
        "-f", "chart/${lookup(local.helm_values_files, each.key, "stag-values.yaml")}",
        "-f", "chart/config-values.yaml",
        "--namespace", "default",
        "--wait"
      ]
      env = [
        "CLOUDSDK_COMPUTE_REGION=${local.region}",
        "CLOUDSDK_CONTAINER_CLUSTER=${local.cluster_name}",
      ]
    }

    options {
      machine_type = "E2_HIGHCPU_8"
      logging      = "CLOUD_LOGGING_ONLY"
    }
  }

  service_account = google_service_account.cloudbuild_sa.id

  depends_on = [
    google_cloudbuildv2_repository.repos,
    google_service_account.cloudbuild_sa
  ]
}

# -------------------------------------------------------
# Job Scheduler Worker Trigger (EXTRA — was missing before!)
# AWS Equivalent: action "DeployWorkerToEKS" — run_order = 2
# HelmReleaseName = "job-scheduler-worker"
# HelmValuesFiles = "stag-worker-values.yaml,config-values.yaml"
# -------------------------------------------------------
resource "google_cloudbuild_trigger" "job_scheduler_worker_trigger" {
  name        = "${local.prefix}job-scheduler-worker-trigger"
  project     = var.project_id
  location    = local.region
  description = "AWS Equivalent: DeployWorkerToEKS action — job-scheduler-worker Helm deploy"

  repository_event_config {
    repository = google_cloudbuildv2_repository.repos["job-scheduler"].id
    push {
      branch = var.branch_name.name
    }
  }

  build {
    timeout = "3600s"

    # AWS Equivalent: DeployWorkerToEKS
    # HelmReleaseName = "job-scheduler-worker"
    # HelmChartLocation = "chart"
    # HelmValuesFiles = "stag-worker-values.yaml,config-values.yaml"
    step {
      name = "alpine/helm:3.14.0"
      id   = "helm-deploy-worker"
      args = [
        "upgrade", "--install",
        "job-scheduler-worker",             # HelmReleaseName
        "./chart",                           # HelmChartLocation
        "--set", "image.tag=$COMMIT_SHA",
        "--set", "image.repository=${local.region}-docker.pkg.dev/${var.project_id}/${local.prefix}job-scheduler",
        "-f", "chart/stag-worker-values.yaml",  # HelmValuesFiles
        "-f", "chart/config-values.yaml",
        "--namespace", "default",
        "--wait"
      ]
      env = [
        "CLOUDSDK_COMPUTE_REGION=${local.region}",
        "CLOUDSDK_CONTAINER_CLUSTER=${local.cluster_name}",
      ]
    }

    options {
      machine_type = "E2_HIGHCPU_8"
      logging      = "CLOUD_LOGGING_ONLY"
    }
  }

  service_account = google_service_account.cloudbuild_sa.id

  depends_on = [
    google_cloudbuildv2_repository.repos,
    google_service_account.cloudbuild_sa
  ]
}

# -------------------------------------------------------
# Gamification GitHub Repo Link
# AWS Equivalent: FullRepositoryId = var.gamification_repo.fullrepositoryid
#                 in aws_codepipeline "gamification" Source stage
# -------------------------------------------------------
resource "google_cloudbuildv2_repository" "gamification_repo" {
  name              = "${local.prefix}gamification"
  project           = var.project_id
  location          = local.region
  parent_connection = google_cloudbuildv2_connection.github.id
  remote_uri        = "https://github.com/${var.gamification_repo.fullrepositoryid}.git"
}

# -------------------------------------------------------
# Gamification Pipeline
# AWS Equivalent: aws_codepipeline "gamification" in codepipeline.tf
# Stages: Source → Build → DBMigrations → DeployToEKS(Helm) + DeployWorkerToEKS(Helm)
# HelmReleaseName = "gamification"
# HelmValuesFiles = "jobs-values.yaml,config-values.yaml"
# Extra: DeployWorkerToEKS → HelmReleaseName = "gamification-worker"
#        HelmValuesFiles = "worker-values.yaml,config-values.yaml"
# ACTIVE in AWS codepipeline.tf (not commented)
# -------------------------------------------------------
resource "google_clouddeploy_delivery_pipeline" "gamification" {
  name        = "${local.prefix}gamification"
  project     = var.project_id
  location    = local.region
  description = "AWS Equivalent: aws_codepipeline gamification — Source→Build→DBMigrations→DeployHelm+DeployWorkerHelm"

  labels = local.default_labels

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.gke_target.target_id
      # AWS Equivalent: HelmValuesFiles = "jobs-values.yaml,config-values.yaml"
      profiles  = ["jobs-values", "config-values"]
    }
  }
}

# -------------------------------------------------------
# Gamification Worker Pipeline
# AWS Equivalent: action "DeployWorkerToEKS" (run_order = 2) in gamification codepipeline
# HelmReleaseName = "gamification-worker"
# HelmValuesFiles = "worker-values.yaml,config-values.yaml"
# -------------------------------------------------------
resource "google_clouddeploy_delivery_pipeline" "gamification_worker" {
  name        = "${local.prefix}gamification-worker"
  project     = var.project_id
  location    = local.region
  description = "AWS Equivalent: DeployWorkerToEKS action in gamification pipeline — gamification-worker Helm deploy"

  labels = local.default_labels

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.gke_target.target_id
      # AWS Equivalent: HelmValuesFiles = "worker-values.yaml,config-values.yaml"
      profiles  = ["worker-values", "config-values"]
    }
  }
}

# -------------------------------------------------------
# Gamification Pipeline Trigger
# AWS Equivalent: Full aws_codepipeline "gamification"
# Source(GitHub) → Build(Docker) → DBMigrations → DeployToEKS(Helm) + DeployWorkerToEKS(Helm)
# -------------------------------------------------------
resource "google_cloudbuild_trigger" "gamification_trigger" {
  name        = "${local.prefix}gamification-trigger"
  project     = var.project_id
  location    = local.region
  description = "AWS Equivalent: CodePipeline gamification — Source+Build+DBMigrations+DeployToEKS+DeployWorkerToEKS"

  # AWS Equivalent: BranchName = var.branch_name.name
  repository_event_config {
    repository = google_cloudbuildv2_repository.gamification_repo.id
    push {
      branch = var.branch_name.name
    }
  }

  build {
    timeout = "3600s"

    # ---
    # Stage 1: Build Docker image
    # AWS Equivalent: Stage "Build" — CodeBuild buildspec docker build (gamification)
    # ---
    step {
      name = "gcr.io/cloud-builders/docker"
      id   = "build"
      args = [
        "build",
        "-t", "${local.region}-docker.pkg.dev/${var.project_id}/${local.prefix}gamification:$COMMIT_SHA",
        "-t", "${local.region}-docker.pkg.dev/${var.project_id}/${local.prefix}gamification:latest",
        "."
      ]
    }

    # Stage 2: Push to Artifact Registry
    # AWS Equivalent: CodeBuild docker push to ECR (gamification repo)
    step {
      name = "gcr.io/cloud-builders/docker"
      id   = "push"
      args = [
        "push", "--all-tags",
        "${local.region}-docker.pkg.dev/${var.project_id}/${local.prefix}gamification"
      ]
    }

    # ---
    # Stage 3: DB Migrations
    # AWS Equivalent: Stage "DBMigrations" → module.db_migrations-gamification.project_name
    # ---
    step {
      name = "${local.region}-docker.pkg.dev/${var.project_id}/${local.prefix}gamification:latest"
      id   = "db-migrate"
      args = ["sh", "-c", "cd /home/node/app && npm run migrate && npm run seed"]
      secret_env = ["DB_PASSWORD"]
    }

    # ---
    # Stage 4: Helm Deploy — Gamification App
    # AWS Equivalent: Stage "DeployToEKS" → action "DeployAppToEKS"
    # HelmReleaseName = "gamification"
    # HelmChartLocation = "chart"
    # HelmValuesFiles = "jobs-values.yaml,config-values.yaml"
    # ---
    step {
      name = "alpine/helm:3.14.0"
      id   = "helm-deploy-gamification"
      args = [
        "upgrade", "--install",
        "gamification",            # HelmReleaseName
        "./chart",                  # HelmChartLocation = "chart"
        "--set", "image.tag=$COMMIT_SHA",
        "--set", "image.repository=${local.region}-docker.pkg.dev/${var.project_id}/${local.prefix}gamification",
        "-f", "chart/jobs-values.yaml",     # HelmValuesFiles = "jobs-values.yaml,config-values.yaml"
        "-f", "chart/config-values.yaml",
        "--namespace", "default",
        "--wait"
      ]
      env = [
        "CLOUDSDK_COMPUTE_REGION=${local.region}",
        "CLOUDSDK_CONTAINER_CLUSTER=${local.cluster_name}",
      ]
    }

    # ---
    # Stage 5: Helm Deploy — Gamification Worker
    # AWS Equivalent: Stage "DeployToEKS" → action "DeployWorkerToEKS" (run_order = 2)
    # HelmReleaseName = "gamification-worker"
    # HelmChartLocation = "chart"
    # HelmValuesFiles = "worker-values.yaml,config-values.yaml"
    # ---
    step {
      name = "alpine/helm:3.14.0"
      id   = "helm-deploy-gamification-worker"
      args = [
        "upgrade", "--install",
        "gamification-worker",     # HelmReleaseName
        "./chart",                  # HelmChartLocation
        "--set", "image.tag=$COMMIT_SHA",
        "--set", "image.repository=${local.region}-docker.pkg.dev/${var.project_id}/${local.prefix}gamification",
        "-f", "chart/worker-values.yaml",   # HelmValuesFiles = "worker-values.yaml,config-values.yaml"
        "-f", "chart/config-values.yaml",
        "--namespace", "default",
        "--wait"
      ]
      env = [
        "CLOUDSDK_COMPUTE_REGION=${local.region}",
        "CLOUDSDK_CONTAINER_CLUSTER=${local.cluster_name}",
      ]
    }

    available_secrets {
      secret_manager {
        version_name = "projects/${var.project_id}/secrets/${local.prefix}db-credentials-gamification/versions/latest"
        env          = "DB_PASSWORD"
      }
    }

    options {
      machine_type = "E2_HIGHCPU_8"
      logging      = "CLOUD_LOGGING_ONLY"
    }
  }

  service_account = google_service_account.cloudbuild_sa.id

  depends_on = [
    google_cloudbuildv2_repository.gamification_repo,
    google_service_account.cloudbuild_sa
  ]
}
