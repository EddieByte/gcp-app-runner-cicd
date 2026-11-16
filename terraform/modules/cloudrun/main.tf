# -----------------------------------------------------------------------------
# Module: cloudrun
#
# Terraform owns the SERVICE (identity, env vars, secret, Cloud SQL connection,
# scaling, ingress, probes). The CI pipeline owns the IMAGE: it deploys new
# revisions with `gcloud run deploy --image`. ignore_changes below keeps the
# two from overwriting each other.
#
# First apply uses Google's sample image so the service can exist before CI
# has built anything; the first release tag replaces it.
#
# Docs: https://cloud.google.com/run/docs/deploying
#       https://cloud.google.com/run/docs/configuring/services/secrets
#       https://cloud.google.com/sql/docs/mysql/connect-run
#       https://cloud.google.com/run/docs/securing/ingress
# -----------------------------------------------------------------------------

resource "google_cloud_run_v2_service" "this" {
  project  = var.project_id
  name     = var.service_name
  location = var.region
  labels   = var.labels

  # Only the load balancer may reach the service; direct *.run.app requests
  # from the internet are rejected. All traffic therefore passes the LB
  # (single entry point for TLS, logging and, later, Cloud Armor).
  ingress = var.ingress

  deletion_protection = var.deletion_protection

  template {
    service_account                  = var.runtime_sa_email
    max_instance_request_concurrency = var.concurrency
    timeout                          = "30s"

    scaling {
      min_instance_count = var.min_instances # 0 = scale to zero, no idle cost
      max_instance_count = var.max_instances # caps cost and DB connections
    }

    # Built-in Cloud SQL connector: mounts a unix socket at
    # /cloudsql/<connection_name>, authenticated with the runtime SA's
    # roles/cloudsql.client. No IPs, no passwords on the network.
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [var.cloudsql_connection_name]
      }
    }

    containers {
      image = var.image

      ports {
        container_port = 8080 # Nginx listens here
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle          = true # CPU only billed while handling requests
        startup_cpu_boost = true # faster cold starts
      }

      env {
        name  = "APP_NAME"
        value = var.app_name
      }
      env {
        name  = "APP_ENV"
        value = var.environment
      }
      env {
        name  = "DB_NAME"
        value = var.db_name
      }
      env {
        name  = "DB_USER"
        value = var.db_user
      }
      env {
        name  = "INSTANCE_CONNECTION_NAME"
        value = var.cloudsql_connection_name
      }
      # Password comes from Secret Manager at instance start; only a reference
      # is stored in the service definition.
      env {
        name = "DB_PASS"
        value_source {
          secret_key_ref {
            secret  = var.db_password_secret_id
            version = "latest"
          }
        }
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      # /healthz never touches the DB, so a DB outage doesn't cause restarts.
      startup_probe {
        http_get {
          path = "/healthz"
          port = 8080
        }
        period_seconds    = 3
        timeout_seconds   = 2
        failure_threshold = 10
      }

      liveness_probe {
        http_get {
          path = "/healthz"
          port = 8080
        }
        period_seconds  = 30
        timeout_seconds = 3
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image, # owned by CI (release tags)
      template[0].revision,            # CI names revisions after the release tag
      client,                          # set by gcloud on each deploy
      client_version,
      traffic,                         # CI may pin traffic during a rollback
    ]
  }
}

# Public invoker: anyone may call the service, but ingress (above) means
# "anyone" can only arrive through the load balancer.
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
