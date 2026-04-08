# ============================================================
# SIXTYGG — Memorystore Redis
# AWS Equivalent: redis.tf
# ============================================================

# -------------------------------------------------------
# Redis Auth Password
# AWS Equivalent: ElastiCache auth_token
# -------------------------------------------------------
resource "random_password" "redis_auth" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "redis_auth" {
  secret_id = "${local.prefix}redis-auth"
  project   = var.project_id
  labels    = local.default_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "redis_auth" {
  secret      = google_secret_manager_secret.redis_auth.id
  secret_data = random_password.redis_auth.result
}

# -------------------------------------------------------
# Memorystore Redis
# AWS Equivalent: aws_elasticache_replication_group
# -------------------------------------------------------
resource "google_redis_instance" "redis" {
  count = var.redis.create_cluster ? 1 : 0

  name           = var.redis.cluster_id
  project        = var.project_id
  region         = local.region
  display_name   = "Sixtygg ${var.environment} Redis"

  # STANDARD_HA = with replica (AWS: create_replication_group = true)
  # BASIC = single node
  tier = var.redis.tier

  memory_size_gb = var.redis.memory_size_gb   # 1GB (AWS: cache.t4g.medium)
  redis_version  = var.redis.version          # REDIS_7_0

  # Private network — not exposed to internet
  # AWS Equivalent: subnet_group_name in private subnets
  authorized_network = google_compute_network.vpc.id

  # Auth — requires password
  # AWS Equivalent: auth_token
  auth_enabled = true

  # TLS
  transit_encryption_mode = "SERVER_AUTHENTICATION"

  # Maintenance window
  # AWS Equivalent: maintenance_window in ElastiCache
  maintenance_policy {
    weekly_maintenance_window {
      day = "SUNDAY"
      start_time {
        hours   = 5
        minutes = 0
        seconds = 0
        nanos   = 0
      }
    }
  }

  # Redis config
  # AWS Equivalent: parameter_group_family = "redis7"
  redis_configs = {
    maxmemory-policy = "allkeys-lru"
  }

  labels = local.default_labels

  depends_on = [google_compute_network.vpc]
}

# ============================================================
# QUEUE Redis — Memorystore
# AWS Equivalent: redis.tf → module "elasticache_queue"
# redis_queue = { cluster_id = "jaackpot-prod-queue", node_type = "cache.m7g.large", ... }
# ============================================================

# -------------------------------------------------------
# Redis Queue Auth Password
# AWS Equivalent: ElastiCache auth_token for queue cluster
# -------------------------------------------------------
resource "random_password" "redis_queue_auth" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "redis_queue_auth" {
  secret_id = "${local.prefix}redis-queue-auth"
  project   = var.project_id
  labels    = local.default_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "redis_queue_auth" {
  secret      = google_secret_manager_secret.redis_queue_auth.id
  secret_data = random_password.redis_queue_auth.result
}

# -------------------------------------------------------
# Memorystore Redis — Queue Instance
# AWS Equivalent: module "elasticache_queue" in redis.tf
# Purpose: Queue processing (separate from main Redis cache)
# -------------------------------------------------------
resource "google_redis_instance" "redis_queue" {
  count = var.redis_queue.create_cluster ? 1 : 0

  name           = var.redis_queue.cluster_id
  project        = var.project_id
  region         = local.region
  display_name   = "Sixtygg ${var.environment} Redis Queue"

  # STANDARD_HA = with replica (AWS: create_replication_group = true)
  # BASIC = single node
  tier = var.redis_queue.tier

  memory_size_gb = var.redis_queue.memory_size_gb
  redis_version  = var.redis_queue.version

  # Private network — not exposed to internet
  # AWS Equivalent: subnet_group_name in private subnets (elasticache_queue)
  authorized_network = google_compute_network.vpc.id

  # Auth — requires password
  # AWS Equivalent: auth_token in elasticache_queue
  auth_enabled = true

  # TLS
  transit_encryption_mode = "SERVER_AUTHENTICATION"

  # Maintenance window
  # AWS Equivalent: maintenance_window = "sun:05:00-sun:09:00" in elasticache_queue
  maintenance_policy {
    weekly_maintenance_window {
      day = "SUNDAY"
      start_time {
        hours   = 5
        minutes = 0
        seconds = 0
        nanos   = 0
      }
    }
  }

  # Redis config
  # AWS Equivalent: parameter_group_family = "redis7" in elasticache_queue
  redis_configs = {
    maxmemory-policy = "allkeys-lru"
  }

  labels = local.default_labels

  depends_on = [google_compute_network.vpc]
}
