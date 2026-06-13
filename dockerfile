# KirayaEase API — Cloud Run Dockerfile
#
# Build: Cloud Build (cloudbuild.yaml)
# Runtime: Cloud Run (asia-south1)
# Python: 3.12-slim

FROM python:3.12-slim AS base

# System deps for psycopg2-binary, pdfkit, reportlab
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    wkhtmltopdf \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ── Dependencies ─────────────────────────────────────────────────────────────
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ── Application code ─────────────────────────────────────────────────────────
COPY . .

# Ensure uploads dir exists (ephemeral on Cloud Run — PDFs are stored in DB)
RUN mkdir -p /app/uploads/leases

# ── Runtime ──────────────────────────────────────────────────────────────────
# Cloud Run injects PORT; default to 8080
ENV PORT=8080
EXPOSE 8080

# Use exec form so SIGTERM is forwarded correctly
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --workers 2 --timeout-keep-alive 75"]
