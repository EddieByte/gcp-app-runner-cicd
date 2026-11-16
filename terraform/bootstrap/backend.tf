# -----------------------------------------------------------------------------
# Bootstrap backend
#
# Chicken-and-egg: this config CREATES the state bucket, so its first run must
# use local state. After the first successful apply:
#   1. Uncomment the block below
#   2. Run: terraform init -migrate-state   (answer "yes")
# Bootstrap state then lives in the bucket under the "bootstrap/" prefix.
# Note: backend blocks cannot use variables, so the bucket name is literal.
# Docs: https://developer.hashicorp.com/terraform/language/backend/gcs
# -----------------------------------------------------------------------------

terraform {
   backend "gcs" {
    bucket = "php-cloudrun-platform-tfstate"
     prefix = "bootstrap"
  }
 }
