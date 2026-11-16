#!/usr/bin/env bash
# =============================================================================
# get-service-ip.sh
#
# Prints the public IP address of the deployed application for an environment.
#
# Why the load balancer's IP?
#   Cloud Run services don't have a fixed public IP; they get a *.run.app URL
#   on Google's shared front end. Our app is published through a global HTTP(S)
#   load balancer with a RESERVED static IP, and Cloud Run only accepts traffic
#   from that load balancer. So "the public IP of the service" = that address.
#
# Usage:
#   ./scripts/get-service-ip.sh <environment> [options]
#
#   environment      dev | prod
#   -p, --project    GCP project ID   (default: $GCP_PROJECT_ID or php-cloudrun-platform)
#   -r, --region     GCP region       (default: $GCP_REGION or europe-west1)
#   --no-check       skip the HTTP health check
#   -h, --help       show this help
#
# Output:
#   stdout: only the IP address, so it can be captured:  IP=$(./get-service-ip.sh dev)
#   stderr: progress messages and the summary
#   logs/get-service-ip.log: every run, timestamped, for future reference
#
# Exit codes:
#   0 success | 1 bad usage | 2 missing tool | 3 not authenticated
#   4 Cloud Run service not found | 5 load balancer IP not found
#
# Runs in Linux, macOS, WSL, Cloud Shell or Git Bash on Windows.
# =============================================================================

# -e: stop on errors  -u: error on unset variables  -o pipefail: catch errors
# inside pipes  -E: let the ERR trap fire inside functions too.
set -Eeuo pipefail

# --- Settings ----------------------------------------------------------------
readonly APP_NAME="php-app"                         # resource naming prefix
readonly SCRIPT_NAME="$(basename "$0")"
readonly REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly LOG_DIR="${REPO_ROOT}/logs"
readonly LOG_FILE="${LOG_DIR}/get-service-ip.log"

PROJECT_ID="${GCP_PROJECT_ID:-php-cloudrun-platform}"
REGION="${GCP_REGION:-europe-west1}"
HEALTH_CHECK=true
ENVIRONMENT=""

# --- Logging -----------------------------------------------------------------
# Messages go to stderr (so stdout stays clean for the IP) and to the log file.
mkdir -p "$LOG_DIR"

log() {
  local level="$1"; shift
  local line
  line="$(date -u '+%Y-%m-%dT%H:%M:%SZ') [${level}] $*"
  echo "$line" >&2
  echo "$line" >> "$LOG_FILE"
}
info()  { log INFO  "$@"; }
warn()  { log WARN  "$@"; }
error() { log ERROR "$@"; }

# Log a clear message and exit with a specific code.
die() {
  local code="$1"; shift
  error "$@"
  exit "$code"
}

# Any command that fails unexpectedly is logged with its line number.
trap 'error "Unexpected failure at line ${LINENO}: ${BASH_COMMAND}"' ERR

usage() {
  # Print the header comment (lines starting with "#", minus the "#").
  sed -n '2,/^# ====/p' "$0" | sed 's/^# \{0,1\}//; /^====/d'
}

# --- 1. Read arguments -------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project)  PROJECT_ID="${2:?--project needs a value}"; shift 2 ;;
    -r|--region)   REGION="${2:?--region needs a value}"; shift 2 ;;
    --no-check)    HEALTH_CHECK=false; shift ;;
    -h|--help)     usage; exit 0 ;;
    -*)            usage >&2; die 1 "Unknown option: $1" ;;
    *)             ENVIRONMENT="$1"; shift ;;
  esac
done

[[ -n "$ENVIRONMENT" ]] || { usage >&2; die 1 "Missing environment. Example: ${SCRIPT_NAME} dev"; }

# --- 2. Adapt configuration to the environment -------------------------------
# Resource names follow the Terraform naming convention: <app>-<env>-...
case "$ENVIRONMENT" in
  dev|prod) ;;
  *) die 1 "Unknown environment '${ENVIRONMENT}'. Use: dev or prod." ;;
esac

SERVICE="${APP_NAME}-${ENVIRONMENT}"            # Cloud Run service
IP_NAME="${APP_NAME}-${ENVIRONMENT}-lb-ip"      # reserved global IP of the LB

info "Run started: env=${ENVIRONMENT} project=${PROJECT_ID} region=${REGION}"

# --- 3. Check prerequisites --------------------------------------------------
command -v gcloud >/dev/null 2>&1 \
  || die 2 "gcloud CLI not found. Install it: https://cloud.google.com/sdk/docs/install"

ACCOUNT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | head -n1 || true)"
[[ -n "$ACCOUNT" ]] || die 3 "Not logged in to gcloud. Run: gcloud auth login"
info "Authenticated as ${ACCOUNT}"

# --- 4. Find the Cloud Run service -------------------------------------------
info "Looking up Cloud Run service '${SERVICE}'..."
if ! SERVICE_INFO="$(gcloud run services describe "$SERVICE" \
      --project "$PROJECT_ID" --region "$REGION" \
      --format='value(status.url,status.latestReadyRevisionName,metadata.annotations."run.googleapis.com/ingress")' 2>&1)"; then
  die 4 "Cloud Run service '${SERVICE}' not found in ${PROJECT_ID}/${REGION}. Has '${ENVIRONMENT}' been deployed? (gcloud said: ${SERVICE_INFO})"
fi
read -r RUN_URL REVISION INGRESS <<< "$SERVICE_INFO"
info "Service found: revision=${REVISION:-unknown} ingress=${INGRESS:-unknown}"

# --- 5. Get the public IP (reserved load balancer address) -------------------
info "Looking up load balancer IP '${IP_NAME}'..."
if ! IP="$(gcloud compute addresses describe "$IP_NAME" \
      --project "$PROJECT_ID" --global --format='value(address)' 2>&1)" || [[ -z "$IP" ]]; then
  die 5 "Reserved IP '${IP_NAME}' not found. The load balancer for '${ENVIRONMENT}' may not exist; apply terraform/envs/${ENVIRONMENT}. (gcloud said: ${IP})"
fi

# --- 6. Optional: confirm the app answers on that IP -------------------------
# A warning, not a failure: the IP is still correct even if the app is down.
if [[ "$HEALTH_CHECK" == true ]]; then
  if command -v curl >/dev/null 2>&1; then
    CODE="$(curl -s -o /dev/null -m 10 -w '%{http_code}' "http://${IP}/healthz" || echo 000)"
    case "$CODE" in
      200)     info  "Health check OK: http://${IP}/healthz returned 200" ;;
      301|308) info  "HTTP redirects to HTTPS (code ${CODE}), so the load balancer is answering" ;;
      *)       warn  "Health check returned ${CODE}. A new load balancer can take ~5-10 min to serve traffic." ;;
    esac
  else
    warn "curl not found; skipping health check"
  fi
fi

# --- 7. Report ---------------------------------------------------------------
{
  echo
  echo "  Environment : ${ENVIRONMENT}"
  echo "  Public IP   : ${IP}"
  echo "  App URL     : http://${IP}"
  echo "  Cloud Run   : ${RUN_URL:-n/a} (internal; reachable only via the load balancer)"
  echo
} >&2

info "Run finished: ${ENVIRONMENT} -> ${IP}"
echo "$IP"
