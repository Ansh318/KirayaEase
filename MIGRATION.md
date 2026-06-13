# KirayaEase: Heroku → Google Cloud + LangGraph → Google ADK Migration

## Overview

| Component | Before | After |
|-----------|--------|-------|
| Hosting | Heroku Dyno | Cloud Run (asia-south1) |
| Database | Heroku Postgres | Cloud SQL PostgreSQL |
| CI/CD | Heroku Git deploy | Cloud Build (Dev branch) |
| Secrets | Heroku Config Vars | Google Secret Manager |
| Scheduler | Heroku Scheduler | Cloud Scheduler |
| AI Orchestration | LangGraph StateGraph | Google ADK Root Agent |
| Agent Model | GPT-4o-mini (LangChain) | Gemini 2.0 Flash (ADK) |

**APIs unchanged. DB schema unchanged. Flutter app unchanged.**

---

## Pre-Migration Checklist

- [ ] GCP project created and billing enabled
- [ ] APIs enabled: Cloud Run, Cloud SQL, Cloud Build, Cloud Scheduler, Secret Manager, Artifact Registry
- [ ] Service accounts created (see IAM section)
- [ ] Heroku Postgres connection string noted

---

## Step 1: Cloud SQL Setup

```bash
# Create Cloud SQL PostgreSQL instance
gcloud sql instances create kiraya-ease-db \
  --database-version=POSTGRES_15 \
  --tier=db-g1-small \
  --region=asia-south1 \
  --storage-type=SSD \
  --storage-size=20GB \
  --backup-start-time=02:00 \
  --availability-type=ZONAL

# Create the database
gcloud sql databases create kirayaease --instance=kiraya-ease-db

# Create a DB user (or use IAM auth — see below)
gcloud sql users create kirayaease_user \
  --instance=kiraya-ease-db \
  --password=<STRONG_PASSWORD>
```

### Database Migration (Heroku Postgres → Cloud SQL)

```bash
# 1. Dump from Heroku
heroku pg:dump DATABASE_URL --app your-heroku-app -f heroku_dump.dump

# 2. Get Cloud SQL public IP (temporarily enable)
CLOUD_SQL_IP=$(gcloud sql instances describe kiraya-ease-db --format='value(ipAddresses[0].ipAddress)')

# 3. Restore into Cloud SQL
pg_restore \
  -h "$CLOUD_SQL_IP" \
  -U kirayaease_user \
  -d kirayaease \
  --no-owner \
  --no-acl \
  heroku_dump.dump

# 4. Verify row counts
psql -h "$CLOUD_SQL_IP" -U kirayaease_user -d kirayaease \
  -c "SELECT relname, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC;"
```

---

## Step 2: Secret Manager

Store every secret from Heroku Config Vars:

```bash
PROJECT_ID=your-gcp-project

_store() {
  echo -n "$2" | gcloud secrets create "KIRAYA_EASE_$1" \
    --project="$PROJECT_ID" \
    --replication-policy=automatic \
    --data-file=- 2>/dev/null || \
  echo -n "$2" | gcloud secrets versions add "KIRAYA_EASE_$1" \
    --project="$PROJECT_ID" \
    --data-file=-
}

# Core secrets (replace values from Heroku Config Vars)
_store DATABASE_URL           ""          # leave blank — Cloud SQL uses connector
_store CLOUD_SQL_INSTANCE     "your-project:asia-south1:kiraya-ease-db"
_store DB_USER                "kirayaease_user"
_store DB_PASSWORD            "<DB_PASSWORD>"
_store DB_NAME                "kirayaease"
_store OPENAI_API_KEY         "<from Heroku>"
_store PINECONE_API_KEY       "<from Heroku>"
_store RAZORPAY_TEST_KEY_ID   "<from Heroku>"
_store RAZORPAY_KEY_SECRET    "<from Heroku>"
_store DOCUSEAL_API_KEY       "<from Heroku>"
_store DOCUSEAL_WEBHOOK_SECRET "<from Heroku>"
_store WHATSAPP_TOKEN         "<from Heroku>"
_store WHATSAPP_PHONE_ID      "<from Heroku>"
_store RESEND_API_KEY         "<from Heroku>"
_store FIREBASE_SERVICE_ACCOUNT_JSON "<from Heroku>"
_store FCM_PROJECT_ID         "<from Heroku>"
_store GOOGLE_CLIENT_ID       "<from Heroku>"
_store GOOGLE_CLIENT_SECRET   "<from Heroku>"
```

---

## Step 3: IAM Setup

```bash
# Service account for Cloud Run
gcloud iam service-accounts create kiraya-ease-run \
  --display-name="KirayaEase Cloud Run SA"

SA_EMAIL="kiraya-ease-run@${PROJECT_ID}.iam.gserviceaccount.com"

# Required roles
for role in \
  roles/cloudsql.client \
  roles/secretmanager.secretAccessor \
  roles/run.invoker; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$role"
done

# Service account for Cloud Scheduler (invokes Cloud Run)
gcloud iam service-accounts create kiraya-ease-scheduler \
  --display-name="KirayaEase Scheduler SA"

SCHED_SA="kiraya-ease-scheduler@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud run services add-iam-policy-binding kiraya-ease-api \
  --region=asia-south1 \
  --member="serviceAccount:${SCHED_SA}" \
  --role="roles/run.invoker"
```

---

## Step 4: Artifact Registry

```bash
# Create Docker repository
gcloud artifacts repositories create kiraya-ease \
  --repository-format=docker \
  --location=asia-south1 \
  --description="KirayaEase container images"

# Grant Cloud Build push access
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
gcloud artifacts repositories add-iam-policy-binding kiraya-ease \
  --location=asia-south1 \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"
```

---

## Step 5: Cloud Build Trigger

```bash
# Connect GitHub repo (one-time in Cloud Console or via gcloud)
# Then create the trigger for the Dev branch:

gcloud builds triggers create github \
  --name="kiraya-ease-dev-deploy" \
  --repo-name="KirayaEase" \
  --repo-owner="<GITHUB_ORG>" \
  --branch-pattern="^Dev$" \
  --build-config="cloudbuild.yaml" \
  --substitutions="_SQL_INSTANCE=kiraya-ease-db,_SERVICE_ACCOUNT=${SA_EMAIL},_DB_USER=kirayaease_user"
```

---

## Step 6: Initial Cloud Run Deployment

```bash
# First deploy (manually to seed the service)
gcloud run deploy kiraya-ease-api \
  --image="asia-south1-docker.pkg.dev/${PROJECT_ID}/kiraya-ease/kiraya-ease-api:latest" \
  --region=asia-south1 \
  --platform=managed \
  --allow-unauthenticated \
  --service-account="${SA_EMAIL}" \
  --add-cloudsql-instances="${PROJECT_ID}:asia-south1:kiraya-ease-db" \
  --set-env-vars="CLOUD_SQL_INSTANCE=${PROJECT_ID}:asia-south1:kiraya-ease-db,DB_NAME=kirayaease,DB_USER=kirayaease_user,GOOGLE_CLOUD_PROJECT=${PROJECT_ID},PRIVATE_IP=1" \
  --min-instances=1 \
  --max-instances=10 \
  --memory=1Gi \
  --cpu=1 \
  --port=8080
```

---

## Step 7: Cloud Scheduler

```bash
SERVICE_URL="https://kirayaease-902326938544.asia-south1.run.app"

PROJECT_ID=your-gcp-project \
REGION=asia-south1 \
SERVICE_URL="$SERVICE_URL" \
OIDC_SA="kiraya-ease-scheduler@${PROJECT_ID}.iam.gserviceaccount.com" \
bash infrastructure/scheduler/deploy_jobs.sh
```

---

## Step 8: DNS / Flutter App Update

Update the API base URL in the Flutter app:

```
Old: https://your-app.herokuapp.com
New: https://kirayaease-902326938544.asia-south1.run.app
```

All endpoint paths are unchanged (`/agent-chat`, `/leases`, `/onboarding`, etc.).

---

## ADK Architecture

```
Flutter App
    ↓ HTTPS (unchanged endpoints)
FastAPI (Cloud Run)
    ↓ app.core.workflow.run_agent()
Google ADK InMemoryRunner
    ↓ routes to sub-agent
RentOS Root Agent (gemini-2.0-flash)
    ├── Lease Agent         → lease_tools.py
    ├── Payment Agent       → rent_tools.py
    ├── Tenant Agent        → rent_tools.py + portfolio_tools.py
    ├── Property Agent      → portfolio_tools.py
    ├── Analytics Agent     → portfolio_tools.py (Text2SQL)
    ├── Reminder Agent      → rent_tools.py
    └── Document Agent      → lease_tools.py
         ↓ ADK Dynamic Workflows (deterministic)
         ├── TenantOnboarding  → app/agents/adk/workflows/tenant_onboarding.py
         ├── LeaseCreation     → app/agents/adk/workflows/lease_creation.py
         ├── PaymentRecon      → app/agents/adk/workflows/payment_reconciliation.py
         ├── MonthEndClosing   → app/agents/adk/workflows/month_end_closing.py
         └── NoticeEviction    → app/agents/adk/workflows/notice_eviction.py
              ↓
         Cloud SQL PostgreSQL (schema unchanged)
         Pinecone / Razorpay / Digio / DocuSeal
```

---

## Rollback

If migration fails:
1. Point Flutter app back to Heroku URL
2. No DB schema changes were made — Heroku Postgres is untouched
3. Heroku dyno can be restarted at any time

---

## Local Development (no changes required)

```bash
# .env stays the same — DATABASE_URL for local psycopg2
cp .env.example .env
# fill in your local values
uvicorn app.main:app --reload --port 8000
```

`GOOGLE_CLOUD_PROJECT` unset → Secret Manager skipped, `DATABASE_URL` used directly.
