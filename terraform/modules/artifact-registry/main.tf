# -----------------------------------------------------------------------------
# Module: artifact-registry
#
# Docker repository for the application image. Artifact Registry is used
# rather than Container Registry (gcr.io), which Google has retired: it adds
# regional repositories, IAM per repository, cleanup policies and immutable tags.
# Docs: https://cloud.google.com/artifact-registry/docs/docker
#       https://cloud.google.com/artifact-registry/docs/repositories/cleanup-policy
# -----------------------------------------------------------------------------

resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  format        = "DOCKER"
  description   = "Container images for ${var.repository_id}"

  # Immutable tags: once v1.2.0 (or sha-abc123) is pushed it can never be
  # overwritten, so a tag always means the exact image that was scanned and
  # tested. Adding a NEW tag to an existing image (promotion) is still allowed.
  docker_config {
    immutable_tags = var.immutable_tags
  }

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

# Read-only access on THIS repository (not project-wide) for identities that
# deploy images. `gcloud run deploy` verifies the caller can read the image
# before creating a revision, so each environment's deployer needs this.
# Docs: https://cloud.google.com/artifact-registry/docs/access-control
resource "google_artifact_registry_repository_iam_member" "readers" {
  for_each   = toset(var.reader_members)
  project    = var.project_id
  location   = google_artifact_registry_repository.this.location
  repository = google_artifact_registry_repository.this.name
  role       = "roles/artifactregistry.reader"
  member     = each.value
}
