# ============================================================
# SIXTYGG — GCP Providers
# AWS Equivalent: providers.tf with AWS + Kubernetes + Helm
# ============================================================

# GCP Provider
provider "google" {
  project = var.project_id
  region  = var.gcp_provider.region
}

# GCP Beta Provider (needed for some GKE features)
provider "google-beta" {
  project = var.project_id
  region  = var.gcp_provider.region
}

# Kubernetes Provider — connects to GKE cluster
# AWS Equivalent: Kubernetes provider with EKS token
provider "kubernetes" {
  host                   = "https://${google_container_cluster.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
}

# Helm Provider — installs charts on GKE
# AWS Equivalent: Helm provider with EKS config
provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
  }
}

# Get current GCP client config (for Kubernetes/Helm auth token)
data "google_client_config" "default" {}
