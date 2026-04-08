# ============================================================
# SIXTYGG — GCP Terraform Variable Values
# Environment: dev (Testing - Low Cost)
# ============================================================

account_name     = "sixtygg"
environment      = "dev"
base_domain_name = "sixty.gg"

project_id = "FILL_YOUR_GCP_PROJECT_ID"

# -------------------------------------------------------
# PROVIDER VERSIONS
# -------------------------------------------------------
google_provider_version     = "5.0.0"
kubernetes_provider_version = "2.0.0"
helm_provider_version       = "2.0.0"

# -------------------------------------------------------
# GCP PROVIDER CONFIG
# -------------------------------------------------------
gcp_provider = {
  region  = "us-east1"
  zone    = "us-east1-b"
  project = "FILL_YOUR_GCP_PROJECT_ID"
}

# -------------------------------------------------------
# NETWORKING (VPC)
# -------------------------------------------------------
vpc = {
  name                         = "sixtygg-dev"
  cidr                         = "10.50.0.0/16"
  public_subnets               = ["10.50.0.0/22", "10.50.4.0/22"]
  private_subnets              = ["10.50.8.0/22", "10.50.12.0/22"]
  enable_nat_gateway           = true
  enable_private_google_access = true
}
# vpc_peering = {
#   old-mng-vpc-to-new = {
#     peer_network = "projects/OTHER_PROJECT_ID/global/networks/OTHER_VPC"
#   }
#   new-mng-to-vtx-nonprd = {
#     peer_network = "projects/OTHER_PROJECT_ID/global/networks/OTHER_VPC"
#   }
#   new-mng-to-vdp-stg = {
#     peer_network = "projects/OTHER_PROJECT_ID/global/networks/OTHER_VPC"
#   }
# }

# vpc_peering_accepter = {
#   old-mng-vpc-to-new = {
#     peer_network = "projects/OTHER_PROJECT_ID/global/networks/OTHER_VPC"
#     auto_accept  = true
#   }
# }

# private_subnets_routes = [
#   { destination_cidr_block = "10.0.0.0/24" },
#   { destination_cidr_block = "10.0.1.0/24" },
#   { destination_cidr_block = "10.0.3.0/24" },
#   { destination_cidr_block = "10.20.0.0/16" },
#   { destination_cidr_block = "10.192.0.0/16" },
# ]

# -------------------------------------------------------
# GKE CLUSTER
# -------------------------------------------------------
gke = {
  name                       = "sixtygg-dev"
  vpc_name                   = "sixtygg-dev"
  version                    = "1.34.4-gke.1047000"
  private_cluster            = true
  enable_private_endpoint    = false
  master_ipv4_cidr_block     = "172.16.0.0/28"

  master_authorized_networks = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  ]

  cluster_addons = {
    http_load_balancing        = true
    horizontal_pod_autoscaling = true
    
    gcs_fuse_csi_driver        = true
    gke_backup_agent           = false
  }

  node_pools = {
    default = {
      name          = "sixtygg-dev-pool"
      machine_type  = "e2-medium"
      min_count     = 0
      max_count     = 15
      desired_count = 2
      disk_size_gb  = 100
      disk_type     = "pd-ssd"
      image_type    = "COS_CONTAINERD"
      auto_repair   = true
      auto_upgrade  = true
      preemptible   = false
      spot          = true
    }
  }
}

# -------------------------------------------------------
# BASTION SERVER
# -------------------------------------------------------
bastion = {
  name         = "sixtygg-dev-bastion"
  machine_type = "e2-medium"
  image        = "ubuntu-os-cloud/ubuntu-2204-lts"
  disk_size    = 50
  disk_type    = "pd-ssd"
  monitoring   = true
}

# -------------------------------------------------------
# CLOUD SQL — Testing (Cheap)
# -------------------------------------------------------
rds = {
  name                = "sixtygg-dev"
  engine_version      = "POSTGRES_15"
  instance_tier       = "db-custom-4-16384"
  disk_size           = 100
  availability_type   = "REGIONAL"
  database_name       = "sixtygg"
  master_username     = "postgres"
  enable_read_replica = true
  deletion_protection = true
}

# -------------------------------------------------------
# MEMORYSTORE REDIS — Testing (Cheap)
# -------------------------------------------------------
redis = {
  cluster_id     = "sixtygg-dev"
  tier           = "STANDARD_HA"
  memory_size_gb = 4
  version        = "REDIS_7_0"
  create_cluster = true
}

# -------------------------------------------------------
# CLOUD STORAGE
# -------------------------------------------------------
active_s3 = {
  name = "sixtygg-dev-active-storage"
}

artifact_s3 = {
  name = "sixtygg-dev-artifacts"
}

# -------------------------------------------------------
# ARTIFACT REGISTRY
# -------------------------------------------------------
ecr = {
  repo1 = {
    enabled         = true
    repository_name = "sixtygg-dev-admin-backend"
  }
  repo2 = {
    enabled         = true
    repository_name = "sixtygg-dev-admin-frontend"
  }
  repo3 = {
    enabled         = true
    repository_name = "sixtygg-dev-user-frontend"
  }
  repo4 = {
    enabled         = true
    repository_name = "sixtygg-dev-user-backend"
  }
  repo5 = {
    enabled         = true
    repository_name = "sixtygg-dev-job-scheduler"
  }
  repo6 = {
    enabled         = true
    repository_name = "sixtygg-dev-gamification"
  }
}

# -------------------------------------------------------
# SSL CERTIFICATE
# -------------------------------------------------------
acm = {
  enabled = true
  domain  = "*.sixty.gg"
}

# -------------------------------------------------------
# APP SECRETS
# -------------------------------------------------------
app_secrets = {
  db-credentials = {
    secret_id = "sixtygg-dev-db-credentials"
    value     = "FILL_BEFORE_APPLY"
  }
  env-user-backend = {
    secret_id = "sixtygg-dev-env-user-backend"
    value     = "FILL_BEFORE_APPLY"
  }
  env-admin-backend = {
    secret_id = "sixtygg-dev-env-admin-backend"
    value     = "FILL_BEFORE_APPLY"
  }
  env-admin-frontend = {
    secret_id = "sixtygg-dev-env-admin-frontend"
    value     = "FILL_BEFORE_APPLY"
  }
  env-user-frontend = {
    secret_id = "sixtygg-dev-env-user-frontend"
    value     = "FILL_BEFORE_APPLY"
  }
  env-job-scheduler = {
    secret_id = "sixtygg-dev-env-job-scheduler"
    value     = "FILL_BEFORE_APPLY"
  }
}

# -------------------------------------------------------
# WORKLOAD IDENTITY
# -------------------------------------------------------
workload_identity = {
  admin-backend-app = {
    namespace       = "default"
    service_account = "admin-backend-app"
    roles           = ["roles/storage.admin"]
  }
  user-backend-app = {
    namespace       = "default"
    service_account = "user-backend-app"
    roles           = ["roles/storage.admin"]
  }
  cloudwatch-agent = {
    namespace       = "kube-system"
    service_account = "cloudwatch-agent"
    roles           = ["roles/logging.logWriter", "roles/monitoring.metricWriter"]
  }
}

# ============================================================
# AWS Equivalent: build, repo, branch_name section
# ============================================================

# -------------------------------------------------------
# CLOUD BUILD PROJECTS
# AWS Equivalent: build { sweepsusa-stag-adminbackend = { ... } }
# -------------------------------------------------------
build = {
  sixtygg-dev-adminbackend = {
    enabled         = true
    image_repo_name = "sixtygg-dev-admin-backend"
    image_tag       = "latest"
    build_timeout   = 3600
    buildspec       = "templates/cloudbuild/build-admin-backend.yaml"
  },
  sixtygg-dev-adminfrontend = {
    enabled         = true
    image_repo_name = "sixtygg-dev-admin-frontend"
    image_tag       = "latest"
    build_timeout   = 3600
    buildspec       = "templates/cloudbuild/build-admin-frontend.yaml"
  },
  sixtygg-dev-userfrontend = {
    enabled         = true
    image_repo_name = "sixtygg-dev-user-frontend"
    image_tag       = "latest"
    build_timeout   = 3600
    buildspec       = "templates/cloudbuild/build-user-frontend.yaml"
  },
  sixtygg-dev-userbackend = {
    enabled         = true
    image_repo_name = "sixtygg-dev-user-backend"
    image_tag       = "latest"
    build_timeout   = 3600
    buildspec       = "templates/cloudbuild/build-user-backend.yaml"
  },
  sixtygg-dev-jobscheduler = {
    enabled         = true
    image_repo_name = "sixtygg-dev-job-scheduler"
    image_tag       = "latest"
    build_timeout   = 3600
    buildspec       = "templates/cloudbuild/build-job-scheduler.yaml"
  },
  sixtygg-dev-gamification = {
    enabled         = true
    image_repo_name = "sixtygg-dev-gamification"
    image_tag       = "latest"
    build_timeout   = 3600
    buildspec       = "templates/cloudbuild/build-gamification.yaml"
  }
}

# -------------------------------------------------------
# GITHUB REPOS
# AWS Equivalent: admin_backend_repo { fullrepositoryid }
# Change these to your actual GitHub org/repo names
# -------------------------------------------------------
admin_backend_repo = {
  fullrepositoryid = "your-org/sixtygg-admin-backend"
}

admin_frontend_repo = {
  fullrepositoryid = "your-org/sixtygg-admin-frontend"
}

user_frontend_repo = {
  fullrepositoryid = "your-org/sixtygg-user-frontend"
}

user_backend_repo = {
  fullrepositoryid = "your-org/sixtygg-user-backend"
}

job_scheduler_repo = {
  fullrepositoryid = "your-org/sixtygg-job-scheduler"
}

# -------------------------------------------------------
# BRANCH NAME
# AWS Equivalent: branch_name { name = "staging" }
# -------------------------------------------------------
branch_name = {
  name = "production"
}

# -------------------------------------------------------
# GITHUB TOKEN
# AWS Equivalent: codestar_connection (OAuth based)
# Fill before apply
# -------------------------------------------------------
github_token               = "FILL_BEFORE_APPLY"
github_app_installation_id = 0

# -------------------------------------------------------
# CLOUDFLARE CONFIG
# AWS Equivalent: external_dns values in eks.tf
# CF_API_TOKEN, CF_API_EMAIL, zoneFilters = zone_id
# -------------------------------------------------------
cloudflare_api_token = "FILL_BEFORE_APPLY"
cloudflare_email     = "FILL_BEFORE_APPLY"
cloudflare_zone_id   = "FILL_BEFORE_APPLY"

# -------------------------------------------------------
# ROLLOUT DEPLOYMENT NAME
# AWS Equivalent: DEPLOYMENT_NAME = "user-backend-app" in module "rollout-deploy"
# -------------------------------------------------------
rollout_deployment_name = "user-backend-app"

# -------------------------------------------------------
# CLOUD SQL — GAMIFICATION DB
# AWS Equivalent: rds2 in terraform.tfvars
# rds2 = { name = "jaackpot-prod-gamification", engine_version = "15.10", instance_class = "db.r5.xlarge", ... }
# -------------------------------------------------------
rds2 = {
  name                = "sixtygg-prod-gamification"
  engine_version      = "POSTGRES_15"
  instance_tier       = "db-custom-4-16384"
  disk_size           = 20
  availability_type   = "REGIONAL"
  database_name       = "sixtygg_gamification"
  master_username     = "postgres"
  enable_read_replica = false
  deletion_protection = false
}

# -------------------------------------------------------
# MEMORYSTORE REDIS — QUEUE
# AWS Equivalent: redis_queue in terraform.tfvars
# redis_queue = { cluster_id = "jaackpot-prod-queue", node_type = "cache.m7g.large", engine_version = "7.0" }
# -------------------------------------------------------
redis_queue = {
  cluster_id     = "sixtygg-prod-queue"
  tier           = "STANDARD_HA"
  memory_size_gb = 4
  version        = "REDIS_7_0"
  create_cluster = true
}

# -------------------------------------------------------
# TERRAFORM STATE BUCKET
# AWS Equivalent: tfstate_s3 = { name = "jaackpot-prod-tf-states" }
# Active in AWS (not commented)
# -------------------------------------------------------
tfstate_s3 = {
  name = "sixtygg-prod-tf-states"
}

# -------------------------------------------------------
# GAMIFICATION GITHUB REPO
# AWS Equivalent: gamification_repo = { fullrepositoryid = "trueigtech/jaackpot-gamification-service" }
# -------------------------------------------------------
gamification_repo = {
  fullrepositoryid = "your-org/sixtygg-gamification-service"
}
