# ============================================================
# SIXTYGG — Certificate Manager
# AWS Equivalent: acm.tf
# ============================================================

# -------------------------------------------------------
# Google Managed SSL Certificate
# AWS Equivalent: aws_acm_certificate with DNS validation
# Auto-renews — same as ACM
# -------------------------------------------------------
resource "google_compute_managed_ssl_certificate" "ssl_cert" {
  count = var.acm.enabled ? 1 : 0

  name    = "${local.prefix}ssl-cert"
  project = var.project_id

  managed {
    # AWS Equivalent: domain = "*.sixty.gg"
    # GCP does not support wildcard in managed certs
    # So we list all subdomains explicitly
    domains = [
      "dev.${var.base_domain_name}",
      "api-dev.${var.base_domain_name}",
      "bo-dev.${var.base_domain_name}",
      "api-bo-dev.${var.base_domain_name}",
      "jobs-dev.${var.base_domain_name}",
      "dev-gamification.${var.base_domain_name}",

    ]
  }
}
