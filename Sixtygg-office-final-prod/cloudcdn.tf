# ============================================================
# SIXTYGG — Cloud CDN
# AWS Equivalent: cloudfront.tf
# NOTE: Comment out hai — production mein enable karna
# ============================================================

# resource "google_compute_backend_bucket" "cdn_backend" {
#   name        = "${local.prefix}cdn-backend"
#   bucket_name = google_storage_bucket.active_storage.name
#   enable_cdn  = true
# }

# resource "google_compute_url_map" "cdn_url_map" {
#   name            = "${local.prefix}cdn-url-map"
#   description     = "CDN URL Map for sixtygg"
#   # AWS Equivalent: aws_cloudfront_distribution aliases = ["sixty.gg"]

#   default_service = google_compute_backend_service.cdn_backend_service.id
# }

# resource "google_compute_backend_service" "cdn_backend_service" {
#   name        = "${local.prefix}cdn-backend-service"
#   protocol    = "HTTPS"
#   port_name   = "https"
#   timeout_sec = 30
#   enable_cdn  = true

#   # AWS Equivalent: origin { domain_name = alb.dns_name }
#   backend {
#     group = google_compute_instance_group.gke_node_group.id
#   }

#   # AWS Equivalent: viewer_certificate { ssl_support_method = "sni-only" }
#   custom_request_headers  = ["X-Forwarded-Proto: https"]
#   custom_response_headers = ["Strict-Transport-Security: max-age=31536000"]

#   cdn_policy {
#     # AWS Equivalent: default_cache_behavior { viewer_protocol_policy = "redirect-to-https" }
#     cache_mode        = "CACHE_ALL_STATIC"
#     client_ttl        = 3600
#     default_ttl       = 3600
#     max_ttl           = 86400
#     serve_while_stale = 86400

#     # AWS Equivalent: forwarded_values { query_string = true, headers = ["Host"] }
#     cache_key_policy {
#       include_host         = true
#       include_query_string = true
#     }
#   }
# }

# resource "google_compute_global_forwarding_rule" "cdn_https" {
#   name       = "${local.prefix}cdn-https"
#   target     = google_compute_target_https_proxy.cdn_https_proxy.id
#   port_range = "443"
#   # AWS Equivalent: aliases = ["sixty.gg"]
#   ip_address = google_compute_global_address.cdn_ip.address
# }

# resource "google_compute_global_address" "cdn_ip" {
#   name    = "${local.prefix}cdn-ip"
#   project = var.project_id
# }

# resource "google_compute_target_https_proxy" "cdn_https_proxy" {
#   name             = "${local.prefix}cdn-https-proxy"
#   url_map          = google_compute_url_map.cdn_url_map.id
#   # AWS Equivalent: acm_certificate_arn = "arn:aws:acm:..."
#   ssl_certificates = [google_compute_managed_ssl_certificate.ssl_cert[0].id]
# }
