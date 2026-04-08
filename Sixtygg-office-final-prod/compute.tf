# ============================================================
# SIXTYGG — Bastion Server (Jump Server)
# AWS Equivalent: ec2.tf + key_pairs.tf
# ============================================================

# -------------------------------------------------------
# SSH Key (auto-generated)
# AWS Equivalent: key_pairs.tf { aws_key_pair }
# -------------------------------------------------------
resource "tls_private_key" "bastion_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "bastion_private_key" {
  content         = tls_private_key.bastion_key.private_key_pem
  filename        = "${path.module}/${local.prefix}bastion-key.pem"
  file_permission = "0600"
}

# -------------------------------------------------------
# Bastion Server
# AWS Equivalent: ec2.tf
# Used for SSH tunneling to access Cloud SQL and Redis
# -------------------------------------------------------
resource "google_compute_instance" "bastion" {
  name         = var.bastion.name
  machine_type = var.bastion.machine_type   # e2-micro (AWS: t2.micro)
  zone         = local.zone
  project      = var.project_id

  tags   = ["${local.prefix}bastion"]
  labels = local.default_labels

  boot_disk {
    initialize_params {
      image = var.bastion.image
      size  = var.bastion.disk_size
      type  = var.bastion.disk_type
    }
  }

  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.public[0].name

    # Public IP for SSH access
    access_config {}
  }

  service_account {
    email  = google_service_account.bastion_sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.bastion_key.public_key_openssh}"
    # Enable OS Login (alternative to metadata SSH keys)
    enable-oslogin = "FALSE"
  }

  # Startup script — install useful tools
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y postgresql-client redis-tools curl wget htop
    # Install Cloud SQL Auth Proxy
    curl -o /usr/local/bin/cloud-sql-proxy \
      https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.0/cloud-sql-proxy.linux.amd64
    chmod +x /usr/local/bin/cloud-sql-proxy
    echo "Bastion setup complete!"
  EOF

  deletion_protection = false

  depends_on = [
    google_compute_subnetwork.public,
    google_service_account.bastion_sa
  ]
}
