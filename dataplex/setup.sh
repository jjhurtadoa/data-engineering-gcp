#!/bin/bash
# dataplex/setup.sh
# Configure Dataplex lake, zones, assets and data quality scan
# Usage: bash dataplex/setup.sh

set -e

PROJECT_ID=$(gcloud config get-value project)
LOCATION=us-central1
echo "Setting up Dataplex for project: ${PROJECT_ID}"

# ── 1. Create Lake ────────────────────────────────────────────────────────────

gcloud dataplex lakes create analytics-lake \
  --location=${LOCATION} \
  --display-name="Analytics Lake" \
  --description="Lake principal del proyecto de analytics sobre thelook ecommerce"

# ── 2. Create Zones ───────────────────────────────────────────────────────────

gcloud dataplex zones create raw-zone \
  --lake=analytics-lake \
  --location=${LOCATION} \
  --type=RAW \
  --display-name="Raw Zone" \
  --resource-location-type=SINGLE_REGION

gcloud dataplex zones create staging-zone \
  --lake=analytics-lake \
  --location=${LOCATION} \
  --type=CURATED \
  --display-name="Staging Zone" \
  --resource-location-type=SINGLE_REGION

gcloud dataplex zones create marts-zone \
  --lake=analytics-lake \
  --location=${LOCATION} \
  --type=CURATED \
  --display-name="Marts Zone" \
  --resource-location-type=SINGLE_REGION

# ── 3. Attach BigQuery datasets as assets ─────────────────────────────────────

gcloud dataplex assets create raw-asset \
  --lake=analytics-lake \
  --zone=raw-zone \
  --location=${LOCATION} \
  --display-name="Raw Dataset" \
  --resource-type=BIGQUERY_DATASET \
  --resource-name=projects/${PROJECT_ID}/datasets/raw

gcloud dataplex assets create staging-asset \
  --lake=analytics-lake \
  --zone=staging-zone \
  --location=${LOCATION} \
  --display-name="Staging Dataset" \
  --resource-type=BIGQUERY_DATASET \
  --resource-name=projects/${PROJECT_ID}/datasets/staging

gcloud dataplex assets create marts-asset \
  --lake=analytics-lake \
  --zone=marts-zone \
  --location=${LOCATION} \
  --display-name="Marts Dataset" \
  --resource-type=BIGQUERY_DATASET \
  --resource-name=projects/${PROJECT_ID}/datasets/marts

# ── 4. Create Data Quality Scan ───────────────────────────────────────────────

gcloud dataplex datascans create data-quality fct-orders-quality-scan \
  --location=${LOCATION} \
  --display-name="fct_orders quality scan" \
  --data-source-resource=//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/marts/tables/fct_orders \
  --data-quality-spec-file=dataplex/dq_fct_orders.yaml

# ── 5. Run the scan ───────────────────────────────────────────────────────────

gcloud dataplex datascans run fct-orders-quality-scan \
  --location=${LOCATION}

echo "Dataplex setup complete."
echo "Check scan results with:"
echo "  gcloud dataplex datascans jobs list --datascan=fct-orders-quality-scan --location=${LOCATION}"
