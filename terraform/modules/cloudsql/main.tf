# -----------------------------------------------------------------------------
# Module: cloudsql
#
# Creates a Cloud SQL for MySQL instance, an application database and user,
# and stores the generated password in Secret Manager. Only the runtime service
# account can read that secret.
#
# Connectivity choice (see docs/decisions): public IP with NO authorised
# networks. Nothing can connect over the network directly; Cloud Run connects
# through the built-in Cloud SQL connector, which authenticates with IAM
# (roles/cloudsql.client) and encrypts traffic. Private IP is the production
# upgrade.
#
# Docs: https://cloud.google.com/sql/docs/mysql/create-instance
#       https://cloud.google.com/sql/docs/mysql/connect-run
#       https://cloud.google.com/secret-manager/docs/overview
# -----------------------------------------------------------------------------

# Instance names can't be reused for ~1 week after deletion, so a random suffix
# lets us destroy and recreate freely during testing.
resource "random_id" "suffix" {
  byte_length = 2
}

# Generated password: never typed by a human, never in tfvars or git.
# Note: it IS stored in Terraform state, which is why the state bucket is
# private with public access prevention enforced.
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "_-" # avoid characters that need escaping in DSNs/shells
}

resource "google_sql_database_instance" "this" {
  project          = var.project_id
  name             = "${var.name_prefix}-mysql-${random_id.suffix.hex}"
  region           = var.region
  database_version = var.database_version

  # Terraform-level guard: refuses `terraform destroy` while true.
  deletion_protection = var.deletion_protection

  settings {
    edition               = "ENTERPRISE" # required for shared-core tiers like db-f1-micro
    tier                  = var.tier
    availability_type     = var.availability_type # ZONAL for dev, REGIONAL (HA) for prod
    disk_type             = "PD_SSD"
    disk_size             = var.disk_size_gb
    disk_autoresize       = true
    disk_autoresize_limit = var.disk_autoresize_limit_gb

    # API-level guard against deletion from the console/gcloud as well.
    deletion_protection_enabled = var.deletion_protection

    user_labels = var.labels

    ip_configuration {
      ipv4_enabled = true # public IP, but...
      # ...no authorized_networks blocks: no IP range may connect directly.
      ssl_mode = "ENCRYPTED_ONLY" # reject unencrypted connections
    }

    # Daily backups + binary logs = point-in-time recovery (see dr.md).
    # Docs: https://cloud.google.com/sql/docs/mysql/backup-recovery/backups
    backup_configuration {
      enabled                        = true
      binary_log_enabled             = true
      start_time                     = "02:00" # UTC, low traffic
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = var.backup_retention_count
      }
    }

    # Patch window: Sunday 03:00 UTC.
    maintenance_window {
      day  = 7
      hour = 3
    }
  }
}

resource "google_sql_database" "app" {
  project   = var.project_id
  instance  = google_sql_database_instance.this.name
  name      = var.database_name
  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

# Application user. Host "%" is safe here because the instance accepts no
# direct network connections; access is only via the IAM-checked connector.
resource "google_sql_user" "app" {
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = var.database_user
  host     = "%"
  password = random_password.db.result
}

# -----------------------------------------------------------------------------
# Secret Manager: DB password
# Cloud Run mounts it as an env var at runtime; it never appears in the image,
# in GitHub, or in the Cloud Run service definition (only a reference does).
# -----------------------------------------------------------------------------
resource "google_secret_manager_secret" "db_password" {
  project   = var.project_id
  secret_id = "${var.name_prefix}-db-password"
  labels    = var.labels

  replication {
    auto {} # Google-managed replication across regions
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db.result
}

# Least privilege: only the runtime SA can read this ONE secret
# (rather than secretAccessor on the whole project).
resource "google_secret_manager_secret_iam_member" "runtime_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.runtime_sa_email}"
}
