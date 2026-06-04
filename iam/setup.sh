#!/bin/bash
# iam/setup.sh
# Configure service accounts and IAM roles for the project
# Usage: bash iam/setup.sh

set -e

PROJECT_ID=$(gcloud config get-value project)
echo "Setting up IAM for project: ${PROJECT_ID}"

# ── 1. Create service accounts ────────────────────────────────────────────────

gcloud iam service-accounts create sa-analyst \
  --display-name="Analista BI" \
  --description="Solo acceso de lectura a marts"

gcloud iam service-accounts create sa-data-engineer \
  --display-name="Ingeniero de Datos" \
  --description="Acceso completo a todas las capas"

gcloud iam service-accounts create sa-dataform \
  --display-name="Dataform Runner" \
  --description="Ejecuta transformaciones y escribe en staging y marts"

# ── 2. Assign project-level roles ─────────────────────────────────────────────

# sa-data-engineer: read all data
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:sa-data-engineer@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataViewer"

# sa-analyst: read all data (PII blocked by policy tags, rows filtered by row access policy)
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:sa-analyst@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataViewer"

# sa-dataform: write transformed data
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:sa-dataform@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"

# All service accounts need to run BQ jobs
for SA in sa-data-engineer sa-analyst sa-dataform; do
  gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/bigquery.jobUser"
done

# ── 3. Allow owner to impersonate sa-analyst for testing ──────────────────────

OWNER_EMAIL=$(gcloud config get-value account)

gcloud iam service-accounts add-iam-policy-binding \
  sa-analyst@${PROJECT_ID}.iam.gserviceaccount.com \
  --member="user:${OWNER_EMAIL}" \
  --role="roles/iam.serviceAccountTokenCreator"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="user:${OWNER_EMAIL}" \
  --role="roles/iam.serviceAccountTokenCreator"

# ── 4. Grant Dataform default SA access to BigQuery ───────────────────────────
# Replace DATAFORM_SA_NUMBER with your actual Dataform service account number
# Format: service-83218031788@gcp-sa-dataform.iam.gserviceaccount.com
# Find it in: console.cloud.google.com/dataform > repository settings

# gcloud projects add-iam-policy-binding ${PROJECT_ID} \
#   --member="serviceAccount:service-83218031788@gcp-sa-dataform.iam.gserviceaccount.com" \
#   --role="roles/bigquery.dataEditor"

# gcloud projects add-iam-policy-binding ${PROJECT_ID} \
#   --member="serviceAccount:service-83218031788@gcp-sa-dataform.iam.gserviceaccount.com" \
#   --role="roles/bigquery.jobUser"

# ── 5. Policy Tags (PII) ──────────────────────────────────────────────────────
# Create taxonomy via REST API (gcloud CLI does not support this directly)

echo "Creating PII taxonomy..."
curl -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  "https://datacatalog.googleapis.com/v1beta1/projects/${PROJECT_ID}/locations/us/taxonomies" \
  -d '{
    "displayName": "Clasificacion de Datos",
    "description": "Taxonomia de sensibilidad para columnas PII",
    "activatedPolicyTypes": ["FINE_GRAINED_ACCESS_CONTROL"]
  }'

echo ""
echo "Copy the taxonomy ID from the response above."
echo "Then create the PII policy tag:"
echo ""
echo "curl -X POST \\"
echo "  -H \"Authorization: Bearer \$(gcloud auth print-access-token)\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  \"https://datacatalog.googleapis.com/v1beta1/projects/\${PROJECT_ID}/locations/us/taxonomies/TAXONOMY_ID/policyTags\" \\"
echo "  -d '{\"displayName\": \"PII\", \"description\": \"Datos personales identificables\"}'"
echo ""
echo "Then apply the PII tag to raw.users columns: email, first_name, last_name"
echo "via BigQuery UI: raw > users > Schema > Edit Schema > Add Policy Tag"

# ── 6. Row Access Policy ──────────────────────────────────────────────────────

echo "Creating row access policy on raw.orders..."
bq query --nouse_legacy_sql "
CREATE OR REPLACE ROW ACCESS POLICY analyst_filter
ON raw.orders
GRANT TO ('serviceAccount:sa-analyst@${PROJECT_ID}.iam.gserviceaccount.com')
FILTER USING (status = 'Complete')"

echo "IAM setup complete."
