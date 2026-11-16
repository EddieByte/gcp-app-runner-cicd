# -----------------------------------------------------------------------------
# Bootstrap: one-off foundation resources everything else depends on.
# Run manually by a human with Owner rights. CI never runs this config.
# -----------------------------------------------------------------------------

# APIs must be enabled before any resource of that service can be created
# (a common surprise coming from AWS, where services are always "on").
# Docs: https://cloud.google.com/service-usage/docs/enable-disable
locals {
  apis = [
    "storage.googleapis.com",        # Cloud Storage (state + static files)
    "iam.googleapis.com",            # service accounts, IAM bindings
    "iamcredentials.googleapis.com", # short-lived tokens (Workload Identity Federation)
    "sts.googleapis.com",            # token exchange (Workload Identity Federation)
    "cloudresourcemanager.googleapis.com",
    "run.googleapis.com",              # Cloud Run
    "sqladmin.googleapis.com",         # Cloud SQL Admin (also used by the Cloud SQL connector)
    "compute.googleapis.com",          # load balancer, IP addresses, NEGs
    "artifactregistry.googleapis.com", # container images
    "secretmanager.googleapis.com",    # DB password
    "cloudbuild.googleapis.com",       # optional image builds
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.apis)
  service  = each.value

  # Never switch APIs off on destroy: other resources (or people) may rely on them.
  disable_on_destroy = false
}

# Remote state bucket for every other Terraform root in this repo.
# Docs: https://cloud.google.com/docs/terraform/resource-management/store-state
resource "google_storage_bucket" "tfstate" {
  name     = "${var.project_id}-tfstate"
  location = var.region

  uniform_bucket_level_access = true       # enforced by org policy anyway
  public_access_prevention    = "enforced" # state can contain secrets

  # Versioning lets us recover a corrupted or overwritten state file.
  # Disabled for now (var.enable_state_versioning = false) to keep the test
  # setup minimal; recommended ON for any shared or production environment.
  versioning {
    enabled = var.enable_state_versioning
  }

  # Keep state history bounded: drop non-current versions after 30 days.
  # Only created when versioning is on (no non-current versions otherwise).
  dynamic "lifecycle_rule" {
    for_each = var.enable_state_versioning ? [1] : []
    content {
      condition {
        days_since_noncurrent_time = 30
      }
      action {
        type = "Delete"
      }
    }
  }

  lifecycle {
    prevent_destroy = true # guard against an accidental `terraform destroy`
  }

  depends_on = [google_project_service.apis]
}
