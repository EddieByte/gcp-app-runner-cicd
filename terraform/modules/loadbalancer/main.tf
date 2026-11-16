# -----------------------------------------------------------------------------
# Module: loadbalancer (global external Application Load Balancer)
#
#   client -> global IP :80 (and :443 if HTTPS on)
#          -> URL map:  /static/*  -> backend bucket (GCS)
#                       /*         -> backend service -> serverless NEG -> Cloud Run
#
# The reserved global IP is the app's stable public address. Cloud Run itself
# has no fixed IP, which is why scripts/get-service-ip.sh reports THIS address.
#
# Docs: https://cloud.google.com/load-balancing/docs/https/setting-up-https-serverless
#       https://cloud.google.com/load-balancing/docs/negs/serverless-neg-concepts
# -----------------------------------------------------------------------------

resource "google_compute_global_address" "this" {
  project = var.project_id
  name    = "${var.name_prefix}-lb-ip"
}

# Serverless NEG: tells the LB "the backend is this Cloud Run service".
resource "google_compute_region_network_endpoint_group" "cloudrun" {
  project               = var.project_id
  name                  = "${var.name_prefix}-run-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.cloud_run_service_name
  }
}

resource "google_compute_backend_service" "app" {
  project               = var.project_id
  name                  = "${var.name_prefix}-run-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"

  backend {
    group = google_compute_region_network_endpoint_group.cloudrun.id
  }

  # Request logs in Cloud Logging (status, latency, client IP) for debugging.
  log_config {
    enable      = true
    sample_rate = 1.0
  }

  # Attach a Cloud Armor policy here in production (WAF, rate limiting).
  security_policy = var.security_policy
}

resource "google_compute_backend_bucket" "static" {
  project     = var.project_id
  name        = "${var.name_prefix}-static-backend"
  bucket_name = var.static_bucket_name
  enable_cdn  = var.enable_cdn
}

resource "google_compute_url_map" "this" {
  project         = var.project_id
  name            = "${var.name_prefix}-url-map"
  default_service = google_compute_backend_service.app.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "app"
  }

  path_matcher {
    name            = "app"
    default_service = google_compute_backend_service.app.id

    path_rule {
      paths   = ["/static/*"]
      service = google_compute_backend_bucket.static.id
    }
  }
}

# --- HTTP (always on) ---------------------------------------------------------
# Port 80 either serves the app directly or, once HTTPS is live and
# redirect_http_to_https = true, answers every request with a 301 to https://.
# Keep the redirect OFF until the certificate shows ACTIVE, or the site goes
# dark while the cert is still provisioning.
locals {
  http_redirect = var.enable_https && var.redirect_http_to_https
}

resource "google_compute_url_map" "http_redirect" {
  count   = local.http_redirect ? 1 : 0
  project = var.project_id
  name    = "${var.name_prefix}-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT" # 301
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "this" {
  project = var.project_id
  name    = "${var.name_prefix}-http-proxy"
  url_map = local.http_redirect ? google_compute_url_map.http_redirect[0].id : google_compute_url_map.this.id
}

resource "google_compute_global_forwarding_rule" "http" {
  project               = var.project_id
  name                  = "${var.name_prefix}-http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.this.id
  port_range            = "80"
  target                = google_compute_target_http_proxy.this.id
  labels                = var.labels
}

# --- HTTPS (optional) ---------------------------------------------------------
# Google-managed certificates need a domain that resolves to the LB IP. With no
# real domain we use <ip-with-dashes>.nip.io, a free wildcard DNS service.
# Provisioning takes 15-60 min after DNS resolves; HTTP keeps working meanwhile.
# Docs: https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs
locals {
  domain = var.domain != "" ? var.domain : "${replace(google_compute_global_address.this.address, ".", "-")}.nip.io"
}

resource "google_compute_managed_ssl_certificate" "this" {
  count   = var.enable_https ? 1 : 0
  project = var.project_id
  name    = "${var.name_prefix}-cert"

  managed {
    domains = [local.domain]
  }
}

resource "google_compute_target_https_proxy" "this" {
  count            = var.enable_https ? 1 : 0
  project          = var.project_id
  name             = "${var.name_prefix}-https-proxy"
  url_map          = google_compute_url_map.this.id
  ssl_certificates = [google_compute_managed_ssl_certificate.this[0].id]
}

resource "google_compute_global_forwarding_rule" "https" {
  count                 = var.enable_https ? 1 : 0
  project               = var.project_id
  name                  = "${var.name_prefix}-https"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.this.id
  port_range            = "443"
  target                = google_compute_target_https_proxy.this[0].id
  labels                = var.labels
}
