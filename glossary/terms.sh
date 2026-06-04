#!/bin/bash
# glossary/terms.sh
# Create Business Glossary and terms in Dataplex Catalog
# Usage: bash glossary/terms.sh

set -e

PROJECT_ID=$(gcloud config get-value project)
LOCATION=us-central1
GLOSSARY_ID=glosario-negocio
TOKEN=$(gcloud auth print-access-token)

echo "Creating Business Glossary for project: ${PROJECT_ID}"

# ── 1. Create Glossary ────────────────────────────────────────────────────────

curl -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "https://dataplex.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/glossaries?glossaryId=${GLOSSARY_ID}" \
  -d '{
    "displayName": "Glosario de Negocio",
    "description": "Definiciones oficiales de métricas y términos de negocio para el dominio de ecommerce"
  }'

echo "Waiting 30 seconds for glossary to be ready..."
sleep 30

PARENT="projects/${PROJECT_ID}/locations/${LOCATION}/glossaries/${GLOSSARY_ID}"

# ── 2. Create Terms ───────────────────────────────────────────────────────────

echo "Creating term: Revenue"
curl -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "https://dataplex.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/glossaries/${GLOSSARY_ID}/terms?termId=revenue" \
  -d "{
    \"displayName\": \"Revenue\",
    \"parent\": \"${PARENT}\",
    \"description\": \"Suma total de sale_price de todos los order_items con status = Complete. No incluye órdenes canceladas, devueltas o en proceso. Fuente: marts.fct_orders columna sale_price.\"
  }"

echo "Creating term: Margin"
curl -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "https://dataplex.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/glossaries/${GLOSSARY_ID}/terms?termId=margin" \
  -d "{
    \"displayName\": \"Margin\",
    \"parent\": \"${PARENT}\",
    \"description\": \"Diferencia entre sale_price y cost por ítem. Calculado como sale_price - cost. Margen positivo indica ganancia, negativo indica venta a pérdida. Fuente: marts.fct_orders columna margin.\"
  }"

echo "Creating term: Active User"
curl -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "https://dataplex.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/glossaries/${GLOSSARY_ID}/terms?termId=active-user" \
  -d "{
    \"displayName\": \"Active User\",
    \"parent\": \"${PARENT}\",
    \"description\": \"Usuario que ha completado al menos una orden con status = Complete en los últimos 90 días. Se mide sobre marts.fct_orders agrupando por user_id y filtrando por order_date.\"
  }"

echo "Creating term: Churn"
curl -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "https://dataplex.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/glossaries/${GLOSSARY_ID}/terms?termId=churn" \
  -d "{
    \"displayName\": \"Churn\",
    \"parent\": \"${PARENT}\",
    \"description\": \"Usuario que tuvo al menos una orden Complete pero no ha realizado ninguna orden en los últimos 90 días. Se calcula comparando la última order_date por user_id contra la fecha actual.\"
  }"

echo "Business Glossary setup complete."
echo "Verify at: https://console.cloud.google.com/dataplex/govern/business-glossary"
