#!/usr/bin/env bash
# Deploy Cloud Scheduler jobs (run once, idempotent — update-or-create).
# Usage: PROJECT_ID=my-project OIDC_SA=sa@proj.iam.gserviceaccount.com bash deploy_jobs.sh

set -euo pipefail

PROJECT_ID="${PROJECT_ID:?Set PROJECT_ID}"
REGION="${REGION:-asia-south1}"
SERVICE_URL="https://kirayaease-902326938544.asia-south1.run.app"
OIDC_SA="${OIDC_SA:?Set OIDC_SA (Cloud Run invoker service account)}"

_upsert_job() {
  local name="$1" schedule="$2" uri="$3" description="$4"
  if gcloud scheduler jobs describe "$name" --project="$PROJECT_ID" --location="$REGION" &>/dev/null; then
    echo "Updating job: $name"
    gcloud scheduler jobs update http "$name" \
      --project="$PROJECT_ID" \
      --location="$REGION" \
      --schedule="$schedule" \
      --time-zone="Asia/Kolkata" \
      --uri="$uri" \
      --http-method=POST \
      --oidc-service-account-email="$OIDC_SA" \
      --oidc-token-audience="$SERVICE_URL" \
      --attempt-deadline=300s \
      --max-retry-attempts=3
  else
    echo "Creating job: $name"
    gcloud scheduler jobs create http "$name" \
      --project="$PROJECT_ID" \
      --location="$REGION" \
      --schedule="$schedule" \
      --time-zone="Asia/Kolkata" \
      --uri="$uri" \
      --http-method=POST \
      --oidc-service-account-email="$OIDC_SA" \
      --oidc-token-audience="$SERVICE_URL" \
      --attempt-deadline=300s \
      --max-retry-attempts=3 \
      --description="$description"
  fi
}

_upsert_job \
  "kiraya-ease-landlord-push" \
  "0 7 * * *" \
  "${SERVICE_URL}/internal/jobs/landlord-push" \
  "Daily push: rent due, overdue, lease expiry"

_upsert_job \
  "kiraya-ease-rent-email-reminders" \
  "30 7 * * *" \
  "${SERVICE_URL}/internal/jobs/rent-email-reminders" \
  "Daily rent email reminders to tenants"

echo "Cloud Scheduler jobs deployed to: $SERVICE_URL"
