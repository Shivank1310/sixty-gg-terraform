# ============================================================
# SIXTYGG — Firewall Rules
# AWS Equivalent: security_groups.tf
# ============================================================

# -------------------------------------------------------
# Allow SSH to Bastion
# AWS Equivalent: bastion security group ingress port 22
# -------------------------------------------------------
resource "google_compute_firewall" "allow_ssh_bastion" {
  name        = "${local.prefix}allow-ssh-bastion"
  project     = var.project_id
  network     = google_compute_network.vpc.id
  description = "Allow SSH to bastion server"
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${local.prefix}bastion"]
}

# -------------------------------------------------------
# Allow internal traffic (node to node)
# AWS Equivalent: node_security_group ingress_self_all
# -------------------------------------------------------
resource "google_compute_firewall" "allow_internal" {
  name        = "${local.prefix}allow-internal"
  project     = var.project_id
  network     = google_compute_network.vpc.id
  description = "Allow internal traffic between all resources"
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.vpc.cidr]
}

# -------------------------------------------------------
# Allow GKE Master to Nodes (ephemeral ports)
# AWS Equivalent: cluster_security_group_additional_rules
#   egress_nodes_ephemeral_ports_tcp
# -------------------------------------------------------
resource "google_compute_firewall" "allow_gke_master_to_nodes" {
  name        = "${local.prefix}allow-gke-master-nodes"
  project     = var.project_id
  network     = google_compute_network.vpc.id
  description = "Allow GKE master to communicate with nodes"
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["1025-65535", "443", "10250"]
  }

  # GKE master CIDR
  source_ranges = [var.gke.master_ipv4_cidr_block]
  target_tags   = ["${local.prefix}gke-node"]
}

# -------------------------------------------------------
# Allow Health Check traffic from GCP LB
# AWS Equivalent: Target Group health checks (automatic in AWS)
# -------------------------------------------------------
resource "google_compute_firewall" "allow_health_checks" {
  name        = "${local.prefix}allow-health-checks"
  project     = var.project_id
  network     = google_compute_network.vpc.id
  description = "Allow GCP Load Balancer health check probes"
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
  }

  # GCP health checker fixed IP ranges
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["${local.prefix}gke-node"]
}

# -------------------------------------------------------
# Allow egress (outbound) — all traffic
# AWS Equivalent: egress rules allow all
# -------------------------------------------------------
resource "google_compute_firewall" "allow_egress" {
  name        = "${local.prefix}allow-egress"
  project     = var.project_id
  network     = google_compute_network.vpc.id
  description = "Allow all outbound traffic"
  direction   = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
}
