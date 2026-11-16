output "instance_name" {
  value = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "project:region:instance, used by Cloud Run's Cloud SQL connection (/cloudsql/<this>)."
  value       = google_sql_database_instance.this.connection_name
}

output "database_name" {
  value = google_sql_database.app.name
}

output "database_user" {
  value = google_sql_user.app.name
}

output "password_secret_id" {
  description = "Secret Manager secret ID holding the DB password (referenced by Cloud Run)."
  value       = google_secret_manager_secret.db_password.secret_id
}
