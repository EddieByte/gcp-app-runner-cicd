# -----------------------------------------------------------------------------
# Module: storage (static files bucket)
#
# Public-read bucket served through the load balancer as a backend bucket for
# /static/*. Objects are stored under the "static/" prefix because a backend
# bucket maps the full URL path to the object name (/static/x.css -> static/x.css).
#
# Writes: only this environment's deployer SA (CI syncs app/public/static on
# each release). Reads: anyone (it's public web content, nothing sensitive).
# Docs: https://cloud.google.com/load-balancing/docs/https/ext-load-balancer-backend-buckets
#       https://cloud.google.com/storage/docs/access-control/making-data-public
# -----------------------------------------------------------------------------

resource "google_storage_bucket" "static" {
  project  = var.project_id
  name     = var.bucket_name
  location = var.region
  labels   = var.labels

  uniform_bucket_level_access = true        # required by org policy; IAM-only access
  public_access_prevention    = "inherited" # allow the allUsers grant below
  force_destroy               = var.force_destroy

  # Cheap insurance against bad syncs: soft-deleted objects recoverable 7 days.
  soft_delete_policy {
    retention_duration_seconds = 604800
  }
}

# Public read for web assets.
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.static.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# CI writer (this environment's deployer SA): scoped to this bucket only.
resource "google_storage_bucket_iam_member" "writers" {
  for_each = toset(var.writer_members)
  bucket   = google_storage_bucket.static.name
  role     = "roles/storage.objectAdmin"
  member   = each.value
}
