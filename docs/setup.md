# Setup and operations guide

Step-by-step reference for building, configuring, running and troubleshooting the project. For the overview, see the [README](../README.md).

---

## Prerequisites

| Tool | Version used | Check |
|---|---|---|
| Google Cloud project with billing | `php-cloudrun-platform` | `gcloud projects describe <id>` |
| gcloud CLI | latest | `gcloud version` |
| Terraform | ≥ 1.5 (used 1.14) | `terraform version` |
| Git | any | `git --version` |
| Docker (local runs only) | any | `docker version` |

Your account needs **Owner** on the project for the first setup (bootstrap creates IAM resources).

---

## Set up authentication and variables

### Authenticate

Terraform uses **Application Default Credentials (ADC)**, which is a *separate* login from the gcloud CLI. Run both:

```bash
gcloud auth login                                   # for gcloud commands
gcloud config set project php-cloudrun-platform
gcloud auth application-default login               # for Terraform
gcloud auth application-default set-quota-project php-cloudrun-platform
```

Check it worked:

```bash
gcloud auth list                                    # your account marked *
gcloud auth application-default print-access-token  # prints a token
```

> No service-account key files are used anywhere. Locally you use your own login; CI uses Workload Identity Federation.

### Terraform variables

Each Terraform folder has a `terraform.tfvars.example`. Copy it to `terraform.tfvars` (git-ignored) and adjust:

```bash
cp terraform/bootstrap/terraform.tfvars.example terraform/bootstrap/terraform.tfvars
cp terraform/envs/dev/terraform.tfvars.example   terraform/envs/dev/terraform.tfvars
```

The main variables:

| Variable | Where | Meaning | Example |
|---|---|---|---|
| `project_id` | both | GCP project | `php-cloudrun-platform` |
| `region` | both | Region for all regional resources | `europe-west1` |
| `github_repository` | bootstrap | Repo allowed to deploy via OIDC | `EddieByte/gcp-app-runner-cicd` |
| `enable_state_versioning` | bootstrap | Keep old state versions | `false` (dev) / `true` (prod) |
| `environment` | dev | Environment name, used in resource names | `dev` |
| `db_tier` | dev | Cloud SQL machine size | `db-f1-micro` |
| `db_name`, `db_user` | dev | App database and user | `app` |
| `min_instances`, `max_instances` | dev | Cloud Run scaling | `0`, `3` |
| `enable_https` | dev | Managed certificate on `<ip>.nip.io` | `false` |
| `redirect_http_to_https` | dev | 301 HTTP → HTTPS (only once cert is ACTIVE) | `false` |

You can also pass any variable as an environment variable, e.g. `export TF_VAR_project_id=php-cloudrun-platform`.

The **DB password is never a variable.** Terraform generates it and stores it in Secret Manager.

---

## Deploy the infrastructure (Terraform)

There are two Terraform "roots", applied in order:

| Root | Creates | State |
|---|---|---|
| `terraform/bootstrap` | APIs, state bucket, GitHub OIDC pool, CI service accounts | first local, then migrated into the bucket |
| `terraform/envs/dev` | Service accounts, Artifact Registry, Cloud SQL, secret, static bucket, Cloud Run, load balancer | `gs://php-cloudrun-platform-tfstate/env/dev` |

### Step 1: Bootstrap (once)

The state bucket can't hold the state of the code that creates it, so bootstrap starts with local state and then moves it into the bucket.

```bash
cd terraform/bootstrap
terraform init
terraform apply                 # ~12 APIs + bucket + WIF + CI identities
```

Then uncomment the `backend "gcs"` block in `backend.tf` and move the state:

```bash
terraform init -migrate-state   # answer "yes"
```

### Step 2: The dev environment

```bash
cd ../envs/dev
terraform init
terraform plan -out=tfplan      # review before applying
terraform apply tfplan          # Cloud SQL takes ~10-15 min
terraform output
```

Key outputs:

| Output | Use |
|---|---|
| `app_url` | Open in a browser |
| `lb_ip_address` | The app's public IP |
| `github_environment_vars` | Values for the GitHub `dev` environment |
| `db_connection_name` | Cloud SQL connection string used by Cloud Run |

> **First apply:** Cloud Run starts with Google's sample "hello" image. The first release tag replaces it with the real app. Terraform then ignores the image so it never undoes a release.

> **New load balancer:** allow **5-10 minutes** after the first apply before the IP serves traffic.

---

## Configure GitHub

**Settings → Secrets and variables → Actions**

Get the values from Terraform:

```bash
terraform -chdir=terraform/bootstrap output github_vars
terraform -chdir=terraform/envs/dev  output github_environment_vars
```

**Repository variables** (not sensitive: they only work for tokens from this repo with the right tag):

| Name | Value |
|---|---|
| `GCP_PROJECT_ID` | `php-cloudrun-platform` |
| `GCP_REGION` | `europe-west1` |
| `GAR_REPOSITORY` | `php-app` |
| `IMAGE_NAME` | `php-app` |
| `WIF_PROVIDER` | from `github_vars` |
| `BUILDER_SA` | from `github_vars` |
| `SCANNER_SA` | from `github_vars` |
| `CLOUD_RUN_SERVICE_DEV` | `php-app-dev` |
| `BUILD_BACKEND` *(optional)* | `cloudbuild` (default if unset) or `github`: which builder builds, scans and pushes the image |

**Repository secret:**

| Name | Purpose |
|---|---|
| `CI_DB_PASSWORD` | Password for the throwaway MySQL used by integration tests in CI. The real DB password never passes through GitHub. |

**Environment `dev`** (Settings → Environments → `dev`), with a deployment tag rule `dev-v*`:

| Name | Value |
|---|---|
| `DEPLOYER_SA` | from `github_environment_vars` |
| `CLOUD_RUN_SERVICE` | `php-app-dev` |
| `STATIC_BUCKET` | `php-cloudrun-platform-dev-static` |
| `APP_URL` | `http://34.95.123.251` (or the HTTPS URL) |

---

## Access the application

> IPs shown here are examples from earlier dev builds. It changes whenever the environment is rebuilt; get the current one with `./scripts/get-service-ip.sh dev` (Bash) or `scripts\get-service-ip.cmd dev` (cmd/PowerShell).

| URL | Expected |
|---|---|
| http://34.95.123.251 | Status page: revision, PHP version, **Connected · MySQL 8.0**, visit counter |
| http://34.95.123.251/healthz | `{"status":"ok"}` (process is up; never touches the DB) |
| http://34.95.123.251/readyz | `{"status":"ok","db":"ok"}` (DB reachable) |
| http://34.95.123.251/static/style.css | CSS served from **Cloud Storage** |
| `https://php-app-dev-….run.app` | **Blocked** on purpose (load-balancer-only ingress) |

Type `http://` explicitly: browsers try HTTPS first, which only works once HTTPS is enabled.

**Enabling HTTPS** (no domain needed):

1. Set `enable_https = true` and apply. The certificate is issued for `34-95-123-251.nip.io`.
2. Wait until it's `ACTIVE` (15-60 min):
   ```bash
   gcloud compute ssl-certificates describe php-app-dev-cert --global --format="value(managed.status)"
   ```
3. Set `redirect_http_to_https = true` and apply.
4. Update `APP_URL` in the GitHub `dev` environment to the HTTPS URL.

---

## Run locally

The same image as Cloud Run, plus MySQL:

```bash
docker compose up --build
# open http://localhost:8080
```

Locally the app connects over TCP (`DB_HOST=db`); on Cloud Run it uses the Cloud SQL socket. `app/src/Config.php` picks automatically.

**Tests:**

```bash
cd app
composer install
vendor/bin/phpunit --testsuite unit           # no database needed
DB_HOST=127.0.0.1 DB_NAME=app DB_USER=app DB_PASS=localpass \
  vendor/bin/phpunit --testsuite integration  # needs MySQL (e.g. docker compose up db)
```

**Scan the image yourself:**

```bash
docker build -f docker/Dockerfile -t php-app:local .
trivy image --config trivy.yaml php-app:local
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `could not find default credentials` (Terraform) | ADC not set up | `gcloud auth application-default login` |
| `SERVICE_DISABLED` / quota project errors | API not enabled yet, or ADC charging another project | Wait a minute; `gcloud auth application-default set-quota-project <project>` |
| Browser shows nothing at the IP right after apply | Load balancer still propagating, or browser forced HTTPS | Wait 5-10 min; type `http://` explicitly |
| Status page says **Database: Unreachable** | Cloud Run can't reach Cloud SQL | Cloud Run → Logs, look for `[db]` lines; check the runtime SA has `cloudsql.client` |
| `/static/style.css` returns 404 | Bucket empty | Released yet? Or `gcloud storage rsync app/public/static gs://<bucket>/static --recursive` |
| Pipeline: `Tag ... is not on 'dev'` | Tag created on the wrong branch | Delete the tag, tag a commit on the right branch |
| Pipeline: Trivy gate fails | Fixable HIGH/CRITICAL vulnerability | Read the run Summary; rebuild (new tag) or record an accepted risk in `.trivyignore` with reason + expiry |
| Pipeline: `PERMISSION_DENIED` on auth | Wrong `WIF_PROVIDER`/SA variable, or tag doesn't match the identity's channel | Check the variables; dev tags can only use the dev deployer |
| Pipeline: deploy rolled back | Smoke test failed on the new revision | Cloud Run → Revisions → logs of the new revision |
| Managed certificate stuck in `PROVISIONING` | Normal for up to ~60 min | Keep HTTP serving; enable the redirect only once `ACTIVE` |
| Cloud SQL name already used after destroy | Names are reserved ~1 week | Handled: instance names get a random suffix |

---

## Cost and teardown

**What costs money while running:** the **Cloud SQL** instance and the **load balancer forwarding rule(s)**. Both are billed every hour they exist, even with no traffic. Cloud Run scales to zero, and everything else costs close to nothing.

There are two levels of teardown:

| Level | Removes | Keeps | Use when |
|---|---|---|---|
| **1. Environment (recommended)** | Everything in `terraform/envs/dev`: Cloud SQL (with its data and backups), Cloud Run, load balancer and IP, static bucket, image registry and images, DB secret, app service accounts | The foundation (`terraform/bootstrap`): APIs, state bucket, GitHub sign-in, CI and Cloud Build accounts, which cost ~nothing | Pausing the project; rebuilding later is one `terraform apply` |
| **2. Everything** | Level 1 + the foundation | Nothing | Finished with the project for good |

### Level 1: remove the environment

```bash
cd terraform/envs/dev
terraform plan -destroy -out=destroy.tfplan   # review: only "destroy", nothing "add"
terraform apply destroy.tfplan                # ~5-10 min (Cloud SQL is the slow part)
```

**Check that it's gone.** Every command should print nothing:

```bash
terraform state list
gcloud sql instances list
gcloud run services list --region europe-west1
gcloud compute forwarding-rules list --global
gcloud compute addresses list --global
```

Then confirm in **Billing → Reports** the next day that the daily cost has dropped to about zero.

**Rebuilding later:** `terraform apply` in `terraform/envs/dev`, then update `APP_URL` in the GitHub `dev` environment (the load balancer gets a new IP), and push a new release tag. The database starts empty.

### Level 2: also remove the foundation

Do Level 1 first. The foundation holds the Terraform state bucket, so its own state must be moved out of the bucket before the bucket can be deleted:

1. In `terraform/bootstrap/main.tf`, remove the `lifecycle { prevent_destroy = true }` block on the state bucket.
2. In `terraform/bootstrap/backend.tf`, comment out the `backend "gcs"` block, then move the state back to your machine:
   ```bash
   cd terraform/bootstrap
   terraform init -migrate-state      # answer "yes"
   ```
3. Empty the state bucket (Terraform won't delete a bucket with files in it):
   ```bash
   gcloud storage rm --recursive "gs://php-cloudrun-platform-tfstate/**"
   ```
4. Destroy:
   ```bash
   terraform plan -destroy -out=destroy.tfplan
   terraform apply destroy.tfplan
   ```

**Before rebuilding after Level 2:** undo the two file edits (`git restore terraform/bootstrap`). The GitHub sign-in pool ID `github` stays reserved for 30 days: restore it with `gcloud iam workload-identity-pools undelete github --location=global`, or use a new `wif_pool_id` and update `WIF_PROVIDER` in GitHub. Enabled APIs stay on; they cost nothing.

**Removing the project itself:** `gcloud projects delete php-cloudrun-platform` stops everything at once. It can be restored for 30 days; after that the project ID can never be reused.

---

More: [README](../README.md) · [Design and security](design.md) · [Disaster recovery](../dr.md) · [Extras](../extra.md)
