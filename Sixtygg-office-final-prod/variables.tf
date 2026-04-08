# ============================================================
# SIXTYGG — Variable Definitions
# AWS Equivalent: variables.tf
# ============================================================

# -------------------------------------------------------
# PROJECT
# -------------------------------------------------------
variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "account_name" {
  type        = string
  description = "Account name used as prefix (AWS Equivalent: account_name)"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, stag, prod)"
}

variable "base_domain_name" {
  type        = string
  description = "Base domain name for the project"
  default     = ""
}

# -------------------------------------------------------
# PROVIDER VERSIONS
# AWS Equivalent: aws_provider_version, aws_vpc_module_version etc
# -------------------------------------------------------
variable "google_provider_version" {
  type    = string
  default = "5.0.0"
}

variable "kubernetes_provider_version" {
  type    = string
  default = "2.0.0"
}

variable "helm_provider_version" {
  type    = string
  default = "2.0.0"
}

# -------------------------------------------------------
# GCP PROVIDER CONFIG
# AWS Equivalent: aws_provider { region, profile, allowed_account_ids }
# -------------------------------------------------------
variable "gcp_provider" {
  type = object({
    region  = string
    zone    = string
    project = string
  })
  description = "GCP provider configuration"
}

# -------------------------------------------------------
# NETWORKING (VPC)
# AWS Equivalent: vpc { cidr, public_subnets, private_subnets, ... }
# -------------------------------------------------------
variable "vpc" {
  type = object({
    name                         = string
    cidr                         = string
    public_subnets               = list(string)
    private_subnets              = list(string)
    enable_nat_gateway           = bool
    enable_private_google_access = bool
  })
  description = "VPC network configuration"
}

# -------------------------------------------------------
# GKE CLUSTER
# AWS Equivalent: eks { name, version, node_groups, addons, ... }
# -------------------------------------------------------
variable "gke" {
  type = object({
    name                       = string
    vpc_name                   = string
    version                    = string
    private_cluster            = bool
    enable_private_endpoint    = bool
    master_ipv4_cidr_block     = string
    master_authorized_networks = list(object({
      cidr_block   = string
      display_name = string
    }))
    cluster_addons = object({
      http_load_balancing        = bool
      horizontal_pod_autoscaling = bool
      gcs_fuse_csi_driver        = bool
      gke_backup_agent           = bool
    })
    node_pools = map(object({
      name          = string
      machine_type  = string
      min_count     = number
      max_count     = number
      desired_count = number
      disk_size_gb  = number
      disk_type     = string
      image_type    = string
      auto_repair   = bool
      auto_upgrade  = bool
      preemptible   = bool
      spot          = bool
    }))
  })
  description = "GKE cluster configuration"
}

# -------------------------------------------------------
# BASTION SERVER
# AWS Equivalent: ec2.tf instances + key_pairs.tf
# -------------------------------------------------------
variable "bastion" {
  type = object({
    name         = string
    machine_type = string
    image        = string
    disk_size    = number
    disk_type    = string
    monitoring   = bool
  })
  description = "Bastion server configuration"
}

# -------------------------------------------------------
# CLOUD SQL (PostgreSQL)
# AWS Equivalent: rds { engine, engine_version, instance_class, ... }
# -------------------------------------------------------
variable "rds" {
  type = object({
    name                = string
    engine_version      = string
    instance_tier       = string
    disk_size           = number
    availability_type   = string
    database_name       = string
    master_username     = string
    enable_read_replica = bool
    deletion_protection = bool
  })
  description = "Cloud SQL PostgreSQL configuration"
}

# -------------------------------------------------------
# MEMORYSTORE REDIS
# AWS Equivalent: redis { cluster_id, node_type, engine_version, ... }
# -------------------------------------------------------
variable "redis" {
  type = object({
    cluster_id     = string
    tier           = string
    memory_size_gb = number
    version        = string
    create_cluster = bool
  })
  description = "Memorystore Redis configuration"
}

# -------------------------------------------------------
# CLOUD STORAGE (S3 Equivalent)
# AWS Equivalent: active_s3, artifact_s3
# -------------------------------------------------------
variable "active_s3" {
  type = object({
    name = string
  })
  description = "Active storage bucket (AWS Equivalent: active_s3)"
}

variable "artifact_s3" {
  type = object({
    name = string
  })
  description = "Artifacts storage bucket (AWS Equivalent: artifact_s3)"
}

# -------------------------------------------------------
# ARTIFACT REGISTRY
# AWS Equivalent: ecr { repo { repository_name, enabled } }
# -------------------------------------------------------
variable "ecr" {
  type = map(object({
    enabled         = bool
    repository_name = string
  }))
  description = "Artifact Registry repositories (AWS Equivalent: ECR)"
}

# -------------------------------------------------------
# SECRET MANAGER
# AWS Equivalent: SSM Parameter Store entries
# -------------------------------------------------------
variable "app_secrets" {
  type = map(object({
    secret_id = string
    value     = string
  }))
  description = "App secrets (AWS Equivalent: SSM Parameter Store SecureString)"
}

# -------------------------------------------------------
# SSL / CERTIFICATE
# AWS Equivalent: acm { enabled, domain }
# -------------------------------------------------------
variable "acm" {
  type = object({
    enabled = bool
    domain  = string
  })
  description = "SSL Certificate config (AWS Equivalent: ACM)"
}

# -------------------------------------------------------
# WORKLOAD IDENTITY (Pod Permissions)
# AWS Equivalent: aws_eks_pod_identity_association (admin-backend-app, user-backend-app)
# -------------------------------------------------------
variable "workload_identity" {
  type = map(object({
    namespace       = string
    service_account = string
    roles           = list(string)
  }))
  description = "Workload Identity bindings (AWS Equivalent: Pod Identity / IRSA)"
  default     = {}
}

# -------------------------------------------------------
# CLOUD BUILD
# AWS Equivalent: var.build { for_each map in codebuild.tf }
# module "build" { for_each = try({ for k, v in var.build : k => v if v.enabled == true }, {}) }
# -------------------------------------------------------
variable "build" {
  type = map(object({
    enabled         = bool
    image_repo_name = string
    image_tag       = string
    build_timeout   = number
    buildspec       = string
  }))
  description = "Cloud Build projects (AWS Equivalent: codebuild build map)"
  default     = {}
}

# -------------------------------------------------------
# GITHUB REPOS
# AWS Equivalent: admin_backend_repo, admin_frontend_repo, user_frontend_repo,
#                 user_backend_repo, job_scheduler_repo { fullrepositoryid }
# -------------------------------------------------------
variable "admin_backend_repo" {
  type = object({
    fullrepositoryid = string
  })
  description = "Admin backend GitHub repo (AWS Equivalent: FullRepositoryId)"
}

variable "admin_frontend_repo" {
  type = object({
    fullrepositoryid = string
  })
  description = "Admin frontend GitHub repo"
}

variable "user_frontend_repo" {
  type = object({
    fullrepositoryid = string
  })
  description = "User frontend GitHub repo"
}

variable "user_backend_repo" {
  type = object({
    fullrepositoryid = string
  })
  description = "User backend GitHub repo"
}

variable "job_scheduler_repo" {
  type = object({
    fullrepositoryid = string
  })
  description = "Job scheduler GitHub repo"
}

# -------------------------------------------------------
# BRANCH NAME
# AWS Equivalent: branch_name { name = "staging" }
# -------------------------------------------------------
variable "branch_name" {
  type = object({
    name = string
  })
  description = "Git branch to trigger pipeline (AWS Equivalent: BranchName)"
}

# -------------------------------------------------------
# GITHUB CONNECTION
# AWS Equivalent: aws_codestarconnections_connection "github-stag"
# -------------------------------------------------------
variable "github_token" {
  type        = string
  sensitive   = true
  description = "GitHub Personal Access Token for Cloud Build connection"
}

variable "github_app_installation_id" {
  type        = number
  description = "GitHub App Installation ID for Cloud Build"
  default     = 0
}

# -------------------------------------------------------
# CLOUDFLARE CONFIG
# AWS Equivalent: external_dns values in eks.tf
# CF_API_TOKEN, CF_API_EMAIL, zoneFilters = cloudflare_zone_id
# -------------------------------------------------------
variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API Token (AWS Equivalent: CF_API_TOKEN in external_dns)"
  default     = ""
}

variable "cloudflare_email" {
  type        = string
  description = "Cloudflare account email (AWS Equivalent: CF_API_EMAIL in external_dns)"
  default     = ""
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare Zone ID (AWS Equivalent: zoneFilters in external_dns)"
  default     = ""
}

# -------------------------------------------------------
# ROLLOUT DEPLOYMENT NAME
# AWS Equivalent: DEPLOYMENT_NAME env var in module "rollout-deploy"
# default = "user-backend-app" (same as AWS)
# -------------------------------------------------------
variable "rollout_deployment_name" {
  type        = string
  description = "K8s deployment name for rollout restart (AWS Equivalent: DEPLOYMENT_NAME = 'user-backend-app')"
  default     = "user-backend-app"
}

# -------------------------------------------------------
# CLOUD SQL — GAMIFICATION DB
# AWS Equivalent: rds2 { engine, engine_version, instance_class, ... }
# -------------------------------------------------------
variable "rds2" {
  type = object({
    name                = string
    engine_version      = string
    instance_tier       = string
    disk_size           = number
    availability_type   = string
    database_name       = string
    master_username     = string
    enable_read_replica = bool
    deletion_protection = bool
  })
  description = "Cloud SQL PostgreSQL config for Gamification DB (AWS Equivalent: rds2 / cluster2)"
}

# -------------------------------------------------------
# MEMORYSTORE REDIS — QUEUE
# AWS Equivalent: redis_queue { cluster_id, node_type, engine_version, ... }
# -------------------------------------------------------
variable "redis_queue" {
  type = object({
    cluster_id     = string
    tier           = string
    memory_size_gb = number
    version        = string
    create_cluster = bool
  })
  description = "Memorystore Redis for Queue (AWS Equivalent: elasticache_queue)"
}

# -------------------------------------------------------
# TERRAFORM STATE BUCKET
# AWS Equivalent: tfstate_s3 { name }
# -------------------------------------------------------
variable "tfstate_s3" {
  type = object({
    name = string
  })
  description = "GCS bucket for Terraform state (tfstate_s3 S3 bucket)"
}

# -------------------------------------------------------
# GAMIFICATION GITHUB REPO
# AWS Equivalent: gamification_repo { fullrepositoryid }
# -------------------------------------------------------
variable "gamification_repo" {
  type = object({
    fullrepositoryid = string
  })
  description = "Gamification service GitHub repo (gamification_repo)"
}
