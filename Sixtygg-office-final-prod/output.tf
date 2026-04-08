# ============================================================
# SIXTYGG — Outputs
# AWS Equivalent: output.tf
# ============================================================

# -------------------------------------------------------
# GKE Cluster
# -------------------------------------------------------
output "gke_cluster_name" {
  description = "GKE cluster name (AWS Equivalent: EKS cluster name)"
  value       = google_container_cluster.gke.name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster endpoint URL"
  value       = google_container_cluster.gke.endpoint
  sensitive   = true
}

output "gke_connect_command" {
  description = "Command to connect kubectl to GKE cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.gke.name} --region ${local.region} --project ${var.project_id}"
}

# -------------------------------------------------------
# Networking
# -------------------------------------------------------
output "vpc_name" {
  description = "VPC network name"
  value       = google_compute_network.vpc.name
}

output "private_subnet_names" {
  description = "Private subnet names"
  value       = [for s in google_compute_subnetwork.private : s.name]
}

output "public_subnet_names" {
  description = "Public subnet names"
  value       = [for s in google_compute_subnetwork.public : s.name]
}

# -------------------------------------------------------
# Bastion Server
# -------------------------------------------------------
output "bastion_external_ip" {
  description = "Bastion server public IP (AWS Equivalent: EC2 bastion IP)"
  value       = google_compute_instance.bastion.network_interface[0].access_config[0].nat_ip
}

output "bastion_ssh_command" {
  description = "SSH command to connect to bastion"
  value       = "ssh -i ${local.prefix}bastion-key.pem ubuntu@${google_compute_instance.bastion.network_interface[0].access_config[0].nat_ip}"
}

# -------------------------------------------------------
# Cloud SQL
# -------------------------------------------------------
output "db_connection_name" {
  description = "Cloud SQL connection name (for Cloud SQL Auth Proxy)"
  value       = google_sql_database_instance.primary.connection_name
}

output "db_private_ip" {
  description = "Cloud SQL private IP — use as DB_HOST in app"
  value       = google_sql_database_instance.primary.private_ip_address
}

output "db_name" {
  description = "Database name"
  value       = google_sql_database.database.name
}

output "db_user" {
  description = "Database username"
  value       = google_sql_user.db_user.name
}

# -------------------------------------------------------
# Redis
# -------------------------------------------------------
output "redis_host" {
  description = "Redis host — use as REDIS_HOST in app"
  value       = var.redis.create_cluster ? google_redis_instance.redis[0].host : ""
}

output "redis_port" {
  description = "Redis port"
  value       = var.redis.create_cluster ? google_redis_instance.redis[0].port : 0
}

# -------------------------------------------------------
# Storage
# -------------------------------------------------------
output "active_storage_bucket" {
  description = "Active storage bucket name (AWS Equivalent: S3 bucket)"
  value       = google_storage_bucket.active_storage.name
}

output "artifacts_bucket" {
  description = "Artifacts bucket name"
  value       = google_storage_bucket.artifacts.name
}

# -------------------------------------------------------
# Artifact Registry
# -------------------------------------------------------
output "artifact_registry_urls" {
  description = "Docker image base URLs per service (AWS Equivalent: ECR repo URLs)"
  value = {
    for k, v in google_artifact_registry_repository.repos :
    k => "${local.region}-docker.pkg.dev/${var.project_id}/${v.name}"
  }
}

# -------------------------------------------------------
# Service Accounts
# -------------------------------------------------------
output "cicd_service_account_email" {
  description = "CI/CD Service Account email (for GitHub Actions / Cloud Build)"
  value       = google_service_account.cicd_sa.email
}

output "app_service_account_email" {
  description = "App pods Service Account email"
  value       = google_service_account.app_storage_sa.email
}

# -------------------------------------------------------
# SSL Certificate
# -------------------------------------------------------
output "ssl_certificate_name" {
  description = "SSL Certificate name — check status in GCP Console"
  value       = var.acm.enabled ? google_compute_managed_ssl_certificate.ssl_cert[0].name : ""
}
