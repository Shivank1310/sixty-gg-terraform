# ============================================================
# SIXTYGG — Cloud SQL PostgreSQL
# AWS Equivalent: rds.tf + rds_proxy.tf
# ============================================================

# -------------------------------------------------------
# Auto-generated DB Password
# AWS Equivalent: RDS master password in Secrets Manager
# -------------------------------------------------------
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store DB password in Secret Manager
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${local.prefix}db-password"
  project   = var.project_id
  labels    = local.default_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

# -------------------------------------------------------
# Cloud SQL Primary Instance
# AWS Equivalent: rds.tf → aws_rds_cluster + aws_rds_cluster_instance
# -------------------------------------------------------
resource "google_sql_database_instance" "primary" {
  name             = "${local.prefix}db"
  project          = var.project_id
  region           = local.region
  database_version = var.rds.engine_version   # POSTGRES_15

  deletion_protection = var.rds.deletion_protection

  settings {
    tier              = var.rds.instance_tier   # db-custom-4-16384
    availability_type = var.rds.availability_type  # REGIONAL = HA

    disk_size       = var.rds.disk_size
    disk_type       = "PD_SSD"
    disk_autoresize = true

    # Private IP — not exposed to internet
    # AWS Equivalent: RDS in private subnets, no publicly_accessible
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.vpc.id
      enable_private_path_for_google_cloud_services = true
    }

    # Automated Backups
    # AWS Equivalent: backup_retention_period in RDS
    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = 7
      }
    }

    # Maintenance Window
    # AWS Equivalent: preferred_maintenance_window in RDS
    maintenance_window {
      day          = 7   # Sunday
      hour         = 5   # 5 AM
      update_track = "stable"
    }

    # DB Flags
    # AWS Equivalent: rds_cluster_parameter_group { work_mem = 128MB }
    database_flags {
      name  = "max_connections"
      value = "1000"
    }
    database_flags {
      name  = "work_mem"
      value = "131072"   # 128MB in KB
    }

    # Query Insights
    # AWS Equivalent: performance_insights_enabled = true
    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }

    user_labels = local.default_labels
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# -------------------------------------------------------
# Read Replica
# AWS Equivalent: aws_rds_cluster_instance (reader instance)
# -------------------------------------------------------
resource "google_sql_database_instance" "read_replica" {
  count = var.rds.enable_read_replica ? 1 : 0

  name                 = "${local.prefix}db-replica"
  project              = var.project_id
  region               = local.region
  database_version     = var.rds.engine_version
  master_instance_name = google_sql_database_instance.primary.name

  deletion_protection = false

  replica_configuration {
    failover_target = false
  }

  settings {
    tier              = var.rds.instance_tier
    availability_type = "ZONAL"
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }

    insights_config {
      query_insights_enabled = true
    }

    user_labels = local.default_labels
  }

  depends_on = [google_sql_database_instance.primary]
}

# -------------------------------------------------------
# Database + User
# -------------------------------------------------------
resource "google_sql_database" "database" {
  name     = var.rds.database_name
  instance = google_sql_database_instance.primary.name
  project  = var.project_id
}

resource "google_sql_user" "db_user" {
  name     = var.rds.master_username
  instance = google_sql_database_instance.primary.name
  password = random_password.db_password.result
  project  = var.project_id
}

# -------------------------------------------------------
# Cloud SQL Auth Proxy — Kubernetes Deployment
# AWS Equivalent: rds_proxy.tf → aws_db_proxy
# Runs as sidecar in GKE pods for secure DB connection
# Connection pooling via PgBouncer inside this proxy
# -------------------------------------------------------
resource "kubernetes_deployment" "cloudsql_proxy" {
  metadata {
    name      = "cloudsql-proxy"
    namespace = "default"
    labels = {
      app = "cloudsql-proxy"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "cloudsql-proxy"
      }
    }

    template {
      metadata {
        labels = {
          app = "cloudsql-proxy"
        }
      }

      spec {
        container {
          name  = "cloud-sql-proxy"
          image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.8.0"

          args = [
            "--structured-logs",
            "--port=5432",
            "${google_sql_database_instance.primary.connection_name}",
          ]

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
          }
        }

        service_account_name = "cloudsql-proxy-sa"
      }
    }
  }

  depends_on = [
    google_container_node_pool.node_pools,
    google_sql_database_instance.primary
  ]
}

resource "kubernetes_service" "cloudsql_proxy" {
  metadata {
    name      = "cloudsql-proxy"
    namespace = "default"
  }

  spec {
    selector = {
      app = "cloudsql-proxy"
    }

    port {
      port        = 5432
      target_port = 5432
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.cloudsql_proxy]
}

# ============================================================
# GAMIFICATION Cloud SQL PostgreSQL
# AWS Equivalent: rds.tf → module "cluster2" (rds2)
# Alag database instance for gamification service
# ============================================================

# -------------------------------------------------------
# Auto-generated Gamification DB Password
# AWS Equivalent: RDS2 master password
# -------------------------------------------------------
resource "random_password" "db_password_gamification" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_secret_manager_secret" "db_password_gamification" {
  secret_id = "${local.prefix}db-password-gamification"
  project   = var.project_id
  labels    = local.default_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password_gamification" {
  secret      = google_secret_manager_secret.db_password_gamification.id
  secret_data = random_password.db_password_gamification.result
}

# -------------------------------------------------------
# Gamification Cloud SQL Primary Instance
# AWS Equivalent: module "cluster2" in rds.tf
# rds2 = { name = "jaackpot-prod-gamification", engine = "aurora-postgresql", ... }
# -------------------------------------------------------
resource "google_sql_database_instance" "gamification_primary" {
  name             = "${local.prefix}db-gamification"
  project          = var.project_id
  region           = local.region
  database_version = var.rds2.engine_version   # POSTGRES_15

  deletion_protection = var.rds2.deletion_protection

  settings {
    tier              = var.rds2.instance_tier
    availability_type = var.rds2.availability_type

    disk_size       = var.rds2.disk_size
    disk_type       = "PD_SSD"
    disk_autoresize = true

    # Private IP — not exposed to internet
    # AWS Equivalent: RDS2 in private subnets, no publicly_accessible
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.vpc.id
      enable_private_path_for_google_cloud_services = true
    }

    # Automated Backups
    # AWS Equivalent: backup_retention_period in RDS2
    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = 7
      }
    }

    # Maintenance Window
    # AWS Equivalent: preferred_maintenance_window in RDS2
    maintenance_window {
      day          = 7   # Sunday
      hour         = 5   # 5 AM
      update_track = "stable"
    }

    # DB Flags
    # AWS Equivalent: rds_cluster_parameter_group { work_mem = 128MB }
    database_flags {
      name  = "max_connections"
      value = "1000"
    }
    database_flags {
      name  = "work_mem"
      value = "131072"   # 128MB in KB
    }

    # Query Insights
    # AWS Equivalent: performance_insights_enabled = true in cluster2
    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }

    user_labels = local.default_labels
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# -------------------------------------------------------
# Read Replica for Gamification
# AWS Equivalent: reader instance in cluster2
# -------------------------------------------------------
resource "google_sql_database_instance" "gamification_read_replica" {
  count = var.rds2.enable_read_replica ? 1 : 0

  name                 = "${local.prefix}db-gamification-replica"
  project              = var.project_id
  region               = local.region
  database_version     = var.rds2.engine_version
  master_instance_name = google_sql_database_instance.gamification_primary.name

  deletion_protection = false

  replica_configuration {
    failover_target = false
  }

  settings {
    tier              = var.rds2.instance_tier
    availability_type = "ZONAL"
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }

    insights_config {
      query_insights_enabled = true
    }

    user_labels = local.default_labels
  }

  depends_on = [google_sql_database_instance.gamification_primary]
}

# -------------------------------------------------------
# Gamification Database + User
# -------------------------------------------------------
resource "google_sql_database" "gamification_database" {
  name     = var.rds2.database_name
  instance = google_sql_database_instance.gamification_primary.name
  project  = var.project_id
}

resource "google_sql_user" "gamification_db_user" {
  name     = var.rds2.master_username
  instance = google_sql_database_instance.gamification_primary.name
  password = random_password.db_password_gamification.result
  project  = var.project_id
}
