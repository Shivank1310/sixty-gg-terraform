# ============================================================
# SIXTYGG — VPC Network
# Creates: VPC, Public Subnets, Private Subnets, NAT Gateway
# ============================================================

# -------------------------------------------------------
# VPC Network
# AWS Equivalent: module "vpc" { source = "terraform-aws-modules/vpc/aws" }
# -------------------------------------------------------
resource "google_compute_network" "vpc" {
  name                    = var.vpc.name
  project                 = var.project_id
  auto_create_subnetworks = false   # We create subnets manually
  description             = "VPC for ${local.prefix}project"
}

# AWS Equivalent: aws_vpc_peering_connection (comment out in AWS)
# resource "google_compute_network_peering" "vpc_peering" {
#   for_each     = try(var.vpc_peering, {})
#   name         = each.key
#   network      = google_compute_network.vpc.id
#   peer_network = each.value.peer_network
# }

# AWS Equivalent: vpc_peering_accepter { auto_accept = true } (active in AWS)
# resource "google_compute_network_peering" "vpc_peering_accepter" {
#   for_each     = try(var.vpc_peering_accepter, {})
#   name         = each.key
#   network      = google_compute_network.vpc.id
#   peer_network = each.value.peer_network
# }

# AWS Equivalent: private_subnets_routes (active in AWS)
# resource "google_compute_route" "private_routes" {
#   for_each   = try({ for r in var.private_subnets_routes : r.destination_cidr_block => r }, {})
#   name       = "${local.prefix}private-route-${replace(each.key, "/", "-")}"
#   network    = google_compute_network.vpc.id
#   dest_range = each.value.destination_cidr_block
# }

# -------------------------------------------------------
# Public Subnets
# AWS Equivalent: public_subnets = ["172.20.0.0/22", "172.20.4.0/22"]
# Used for: Load Balancer, Bastion Server
# -------------------------------------------------------
resource "google_compute_subnetwork" "public" {
  count = length(var.vpc.public_subnets)

  name          = "${var.vpc.name}-public-${count.index + 1}"
  project       = var.project_id
  region        = local.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.vpc.public_subnets[count.index]

  # Private Google Access — pods can reach Google APIs
  private_ip_google_access = var.vpc.enable_private_google_access

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# -------------------------------------------------------
# Private Subnets
# Used for: GKE nodes, Cloud SQL, Redis
# -------------------------------------------------------
resource "google_compute_subnetwork" "private" {
  count = length(var.vpc.private_subnets)

  name          = "${var.vpc.name}-private-${count.index + 1}"
  project       = var.project_id
  region        = local.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.vpc.private_subnets[count.index]

  # Private Google Access — required for GKE private nodes
  private_ip_google_access = true

  # Secondary ranges for GKE pods and services
  # AWS Equivalent: vpc-cni uses VPC CIDR for pod IPs
  dynamic "secondary_ip_range" {
    for_each = count.index == 0 ? [1] : []
    content {
      range_name    = "${var.vpc.name}-pods"
      ip_cidr_range = "10.51.0.0/16"
    }
  }

  dynamic "secondary_ip_range" {
    for_each = count.index == 0 ? [1] : []
    content {
      range_name    = "${var.vpc.name}-services"
      ip_cidr_range = "10.52.0.0/16"
    }
  }

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# -------------------------------------------------------
# Cloud Router (needed for NAT Gateway)
# AWS Equivalent: part of VPC module (created automatically)
# -------------------------------------------------------
resource "google_compute_router" "router" {
  count = var.vpc.enable_nat_gateway ? 1 : 0

  name    = "${var.vpc.name}-router"
  project = var.project_id
  region  = local.region
  network = google_compute_network.vpc.id
}

# -------------------------------------------------------
# Cloud NAT (NAT Gateway)
# AWS Equivalent: enable_nat_gateway = true, single_nat_gateway = true
# Allows private subnet resources to reach internet
# -------------------------------------------------------
resource "google_compute_router_nat" "nat" {
  count = var.vpc.enable_nat_gateway ? 1 : 0

  name                               = "${var.vpc.name}-nat"
  project                            = var.project_id
  region                             = local.region
  router                             = google_compute_router.router[0].name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  # Apply NAT to private subnets only
  dynamic "subnetwork" {
    for_each = google_compute_subnetwork.private
    content {
      name                    = subnetwork.value.id
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    }
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# -------------------------------------------------------
# Private Service Access (needed for Cloud SQL private IP)
# AWS Equivalent: DB Subnet Group in private subnets
# -------------------------------------------------------
resource "google_compute_global_address" "private_service_access" {
  name          = "${var.vpc.name}-private-svc-access"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access.name]

  depends_on = [google_compute_global_address.private_service_access]
}
