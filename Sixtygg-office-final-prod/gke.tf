# ============================================================
# SIXTYGG — GKE Cluster
# AWS Equivalent: eks.tf
# Creates: GKE Cluster, Node Pools, Helm Charts
# ============================================================

# -------------------------------------------------------
# GKE Cluster
# AWS Equivalent: module "eks" { source = "terraform-aws-modules/eks/aws" }
# -------------------------------------------------------
resource "google_container_cluster" "gke" {
  name     = local.cluster_name
  project  = var.project_id
  location = local.region

  deletion_protection = false

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.private[0].name

  ip_allocation_policy {
    cluster_secondary_range_name  = "${var.vpc.name}-pods"
    services_secondary_range_name = "${var.vpc.name}-services"
  }

  # AWS Equivalent: cluster_endpoint_private_access, cluster_endpoint_public_access
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.gke.enable_private_endpoint
    master_ipv4_cidr_block  = var.gke.master_ipv4_cidr_block
  }

  # AWS Equivalent: cluster_endpoint_public_access_cidrs
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.gke.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  min_master_version = var.gke.version

  # AWS Equivalent: cluster_addons { coredns, kube-proxy, vpc-cni, metrics-server }
  addons_config {
    http_load_balancing {
      disabled = !var.gke.cluster_addons.http_load_balancing
    }
    horizontal_pod_autoscaling {
      disabled = !var.gke.cluster_addons.horizontal_pod_autoscaling
    }
    gcs_fuse_csi_driver_config {
      enabled = var.gke.cluster_addons.gcs_fuse_csi_driver
    }
    gke_backup_agent_config {
      # AWS Equivalent: enable_velero = true
      enabled = var.gke.cluster_addons.gke_backup_agent
    }
    dns_cache_config {
      # AWS Equivalent: coredns addon
      enabled = true
    }
  }

  # AWS Equivalent: eks-pod-identity-agent + IRSA
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # AWS Equivalent: amazon-cloudwatch-observability addon
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS", "APISERVER", "SCHEDULER", "CONTROLLER_MANAGER"]
  }

  # AWS Equivalent: CloudWatch Container Insights metrics
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS", "APISERVER", "SCHEDULER", "DAEMONSET", "DEPLOYMENT", "STATEFULSET", "STORAGE", "POD", "CADVISOR", "KUBELET"]
    managed_prometheus {
      enabled = true
    }
    advanced_datapath_observability_config {
      enable_metrics = true
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # AWS Equivalent: cluster_security_group_additional_rules + node_security_group_additional_rules
  # Access entries — same as AWS access_entries { cluster-admin, codebuild-admin, rollout-ub-admin }
  # In GKE this is handled via RBAC + Workload Identity

  # AWS Equivalent: enable_karpenter = true + enable_cluster_autoscaler = true (eks_blueprints)
  # GKE uses Node Auto Provisioning (NAP) — built-in Karpenter equivalent
  cluster_autoscaling {
    enabled             = true
    autoscaling_profile = "OPTIMIZE_UTILIZATION"

    resource_limits {
      resource_type = "cpu"
      minimum       = 2
      maximum       = 32
    }
    resource_limits {
      resource_type = "memory"
      minimum       = 4
      maximum       = 128
    }

    # AWS Equivalent: karpenter_node { iam_role_arn, create_iam_role = false }
    auto_provisioning_defaults {
      service_account = google_service_account.gke_node_sa.email
      oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

      management {
        auto_repair  = true
        auto_upgrade = true
      }

      shielded_instance_config {
        enable_secure_boot          = true
        enable_integrity_monitoring = true
      }

      disk_size = 50
      disk_type = "pd-standard"
      image_type = "COS_CONTAINERD"
    }
  }

  # Maintenance window — AWS: preferred_maintenance_window = "sun:05:00-sun:09:00"
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-01T05:00:00Z"
      end_time   = "2024-01-01T09:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SU"
    }
  }

  resource_labels = local.default_labels

  depends_on = [
    google_compute_network.vpc,
    google_compute_subnetwork.private,
    google_service_account.gke_node_sa
  ]
}

# -------------------------------------------------------
# GKE Node Pool
# AWS Equivalent: eks_managed_node_groups
# ami_type = "BOTTLEROCKET_x86_64" → image_type = "COS_CONTAINERD"
# -------------------------------------------------------
resource "google_container_node_pool" "node_pools" {
  for_each = var.gke.node_pools

  name     = each.value.name
  project  = var.project_id
  location = local.region
  cluster  = google_container_cluster.gke.name

  # AWS Equivalent: min_size, max_size, desired_size
  autoscaling {
    min_node_count = each.value.min_count
    max_node_count = each.value.max_count
  }

  initial_node_count = each.value.desired_count

  node_config {
    machine_type = each.value.machine_type
    disk_size_gb = each.value.disk_size_gb
    disk_type    = each.value.disk_type
    image_type   = each.value.image_type

    service_account = google_service_account.gke_node_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # AWS Equivalent: capacity_type = "SPOT"
    spot = each.value.spot

    labels = local.default_labels
    tags   = ["${local.prefix}gke-node"]

    # AWS Equivalent: eks-pod-identity-agent
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # AWS Equivalent: Bottlerocket secure boot
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  # AWS Equivalent: eks_managed_node_group_defaults { auto_repair, auto_upgrade }
  management {
    auto_repair  = each.value.auto_repair
    auto_upgrade = each.value.auto_upgrade
  }

  depends_on = [google_container_cluster.gke]
}

# -------------------------------------------------------
# Helm: External DNS (Cloudflare)
# AWS Equivalent: enable_external_dns = true (eks_blueprints)
# Same: CF_API_TOKEN, domainFilters, zoneFilters, provider: cloudflare
# chart_version = "1.15.0" — same as AWS
# -------------------------------------------------------
resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  namespace        = "external-dns"
  create_namespace = true
  version          = "1.15.0"

  # AWS Equivalent: values = [<<-EOT env: CF_API_TOKEN ... EOT]
  values = [
    <<-EOT
      env:
        - name: CF_API_TOKEN
          value: "${var.cloudflare_api_token}"
        - name: CF_API_EMAIL
          value: "${var.cloudflare_email}"

      domainFilters:
        - ${var.base_domain_name}

      zoneFilters:
        - ${var.cloudflare_zone_id}

      provider: cloudflare
    EOT
  ]

  depends_on = [google_container_node_pool.node_pools]
}

# -------------------------------------------------------
# Helm: Cert Manager
# AWS Equivalent: enable_cert_manager = false (same — disabled)
# -------------------------------------------------------
# AWS Equivalent: enable_cert_manager = false (comment out in AWS eks_blueprints)
# resource "helm_release" "cert_manager" {
#   name             = "cert-manager"
#   repository       = "https://charts.jetstack.io"
#   chart            = "cert-manager"
#   namespace        = "cert-manager"
#   create_namespace = true
#   version          = "v1.14.4"
#   set {
#     name  = "installCRDs"
#     value = "true"
#   }
#   depends_on = [google_container_node_pool.node_pools]
# }

# -------------------------------------------------------
# Helm: Ingress NGINX
# AWS Equivalent: enable_aws_load_balancer_controller = true (eks_blueprints)
# -------------------------------------------------------
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.10.0"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.autoscaling.enabled"
    value = "true"
  }

  set {
    name  = "controller.autoscaling.minReplicas"
    value = "1"
  }

  set {
    name  = "controller.autoscaling.maxReplicas"
    value = "5"
  }

  depends_on = [google_container_node_pool.node_pools]
}
