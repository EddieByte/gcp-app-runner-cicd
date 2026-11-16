# -----------------------------------------------------------------------------
# Module: artifact-registry
#
# Docker repository for the application image. Artifact Registry replaces the
# retired Container Registry (gcr.io), so we use it even though the brief
# mentions GCR.
# Docs: https://cloud.google.com/artifact-registry/docs/docker
#       https://cloud.google.com/artifact-registry/docs/repositories/cleanup-policy
# -----------------------------------------------------------------------------

resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  format        = "DOCKER"
  description   = "Container images for ${var.repository_id}"

  # Cleanup policies keep storage costs down: keep the N most recent images
  # (for rollback), delete anything else older than the retention period.
  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.keep_recent_count
    }
  }

  cleanup_policies {
    id     = "delete-old"
    action = "DELETE"
    condition {
      older_than = "${var.retention_days * 86400}s"
    }
  }
}
