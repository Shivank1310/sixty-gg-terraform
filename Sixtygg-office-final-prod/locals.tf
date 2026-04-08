# ============================================================
# SIXTYGG — Local Values
# ============================================================

locals {
  # Prefix for all resource names
  # AWS Equivalent: prefix = "${var.account_name}-${var.environment}-"
  # e.g. "sixtygg-dev-"
  prefix = "${var.account_name}-${var.environment}-"

  # Default labels for all GCP resources
  # AWS Equivalent: default_tags { Owner, Terraform, Environment }
  default_labels = {
    project     = var.account_name
    environment = var.environment
    terraform   = "true"
    owner       = "ops"
  }

  # GKE cluster name
  cluster_name = "${var.account_name}-${var.environment}"

  # Region and zone from provider config
  region = var.gcp_provider.region
  zone   = var.gcp_provider.zone

  # Helm values files per service
  # AWS Equivalent: HelmValuesFiles in each codepipeline DeployToEKS stage
  # admin-backend  → stag-values.yaml,config-values.yaml
  # admin-frontend → stag-values.yaml
  # user-frontend  → stag-values.yaml
  # user-backend   → stag-values.yaml,config-values.yaml
  # job-scheduler  → stag-jobs-values.yaml,config-values.yaml
  helm_values_files = {
    admin-backend  = "stag-values.yaml"
    admin-frontend = "stag-values.yaml"
    user-frontend  = "stag-values.yaml"
    user-backend   = "stag-values.yaml"
    job-scheduler  = "stag-jobs-values.yaml"
    # AWS Equivalent: HelmValuesFiles = "jobs-values.yaml,config-values.yaml" in gamification pipeline
    gamification   = "jobs-values.yaml"
  }
}
