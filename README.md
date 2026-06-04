# Data Engineering GCP — TheLook Analytics

End-to-end data engineering project built on Google Cloud Platform using the modern data stack. The domain is e-commerce analytics over the public dataset `thelook_ecommerce`.

## Architecture Overview

```
bigquery-public-data.thelook_ecommerce
              │
              ▼
     ┌─────────────────┐
     │   raw (BigQuery) │  ← copied public tables, PII protected
     └────────┬────────┘
              │  Dataform (SQLX)
              ▼
  ┌──────────────────────┐
  │  staging (BigQuery)  │  ← cleaned, typed, no PII
  └──────────┬───────────┘
             │  Dataform (SQLX)
             ▼
  ┌──────────────────────┐
  │  marts (BigQuery)    │  ← dimensional model, business metrics
  └──────────────────────┘
              │
     ┌────────┴────────┐
     │                 │
  Dataplex          Vertex AI
  (Governance)      (Agentic layer)
```

## Stack

| Layer | Technology | Purpose |
|---|---|---|
| Storage | BigQuery | Three-layer architecture: raw, staging, marts |
| Transformation | Dataform (SQLX) | Versioned, tested, documented models |
| Security | IAM + Policy Tags + Row Access Policies | Column and row-level data protection |
| Governance | Dataplex + Knowledge Catalog | Lake management, data quality, lineage |
| Semantic layer | Business Glossary | Unambiguous metric definitions for AI agents |
| Agentic layer | Vertex AI + BigQuery Remote Functions | Natural language queries over business metrics |

## Project Structure

```
data-engineering-gcp/
├── definitions/
│   ├── sources/
│   │   └── sources.js              # raw table declarations
│   ├── staging/
│   │   ├── stg_orders.sqlx
│   │   ├── stg_order_items.sqlx
│   │   ├── stg_users.sqlx
│   │   └── stg_products.sqlx
│   └── marts/
│       ├── dim_users.sqlx
│       ├── dim_products.sqlx
│       ├── fct_orders.sqlx
│       ├── assert_orders_valid_status.sqlx
│       ├── assert_fct_positive_revenue.sqlx
│       └── assert_fct_referential_integrity.sqlx
├── dataplex/
│   ├── dq_fct_orders.yaml          # Data quality scan spec
│   └── setup.sh                    # Lake, zones and assets setup
├── iam/
│   └── setup.sh                    # Service accounts and IAM roles
├── glossary/
│   └── terms.sh                    # Business glossary terms (curl commands)
└── README.md
```

## Data Model

### Source tables (raw)

Copied from `bigquery-public-data.thelook_ecommerce`:

| Table | Description | Rows (approx) |
|---|---|---|
| `raw.orders` | Customer orders | ~125k |
| `raw.order_items` | Individual items per order | ~300k |
| `raw.users` | Customer profiles | ~100k |
| `raw.products` | Product catalog | ~29k |

### Staging models

One-to-one with source tables. Apply cleaning only — no business logic:

| Model | Source | Key transformations |
|---|---|---|
| `stg_orders` | `raw.orders` | Rename columns, truncate timestamps |
| `stg_order_items` | `raw.order_items` | Rename id, round sale_price |
| `stg_users` | `raw.users` | Drop PII columns (email, first_name, last_name) |
| `stg_products` | `raw.products` | Rename id, round prices |

### Mart models

Business-oriented dimensional model (Kimball):

| Model | Type | Description |
|---|---|---|
| `dim_users` | Dimension | User demographics with age_group bucket |
| `dim_products` | Dimension | Product catalog with margin and margin_pct |
| `fct_orders` | Fact | Order items joined with users and products, includes revenue and fulfillment metrics |

### Data quality assertions (Dataform)

Each staging model has inline assertions:
- `uniqueKey` — primary key uniqueness
- `nonNull` — required fields are never null

Custom assertions on marts:
- `assert_orders_valid_status` — status values are within known set
- `assert_fct_positive_revenue` — sale_price is always greater than zero
- `assert_fct_referential_integrity` — all foreign keys resolve to valid dimension records

## Security Model

### IAM — Service accounts

| Service account | Role | Access |
|---|---|---|
| `sa-data-engineer` | `bigquery.dataViewer` | All layers |
| `sa-analyst` | `bigquery.dataViewer` | All layers (PII blocked by policy tags) |
| `sa-dataform` | `bigquery.dataEditor` | staging and marts (write), raw (read) |

### Column-level security (Policy Tags)

Taxonomy: `Clasificacion de Datos` > `PII`

Applied to `raw.users`:
- `email`
- `first_name`
- `last_name`

Users without the `Fine-Grained Reader` role on the taxonomy receive `Access Denied` on those columns, regardless of their IAM role.

### Row-level security

Row access policy on `raw.orders`:
- `sa-analyst` can only see rows where `status = 'Complete'`

## Governance (Dataplex)

### Lake structure

```
analytics-lake (us-central1)
├── raw-zone      (RAW)      → dataset: raw
├── staging-zone  (CURATED)  → dataset: staging
└── marts-zone    (CURATED)  → dataset: marts
```

### Data Quality Scan

Scan: `fct-orders-quality-scan` over `marts.fct_orders`

| Rule | Column | Dimension | Type |
|---|---|---|---|
| Not null | order_id | COMPLETENESS | non_null_expectation |
| Not null | order_item_id | COMPLETENESS | non_null_expectation |
| Positive price | sale_price | VALIDITY | range_expectation > 0 |
| Margin range | margin | VALIDITY | range_expectation -500 to 5000 |
| Valid status | status | VALIDITY | set_expectation |
| Date range | order_date | VALIDITY | range_expectation 2019–2026 |

### Business Glossary

Glossary: `glosario-negocio` in Dataplex Catalog

| Term | Definition |
|---|---|
| **Revenue** | Sum of `sale_price` for all order items with `status = Complete`. Excludes cancelled, returned, or in-process orders. Source: `marts.fct_orders.sale_price` |
| **Margin** | Difference between `sale_price` and `cost` per item (`sale_price - cost`). Positive = profit, negative = loss. Source: `marts.fct_orders.margin` |
| **Active User** | User who has completed at least one order with `status = Complete` in the last 90 days. Measured on `marts.fct_orders` grouped by `user_id` filtered by `order_date` |
| **Churn** | User who had at least one Complete order but has not placed any order in the last 90 days. Calculated by comparing the last `order_date` per `user_id` against current date |

## Setup Guide

### Prerequisites
- GCP project with billing enabled
- `gcloud` CLI authenticated
- GitHub account

### 1. Enable APIs

```bash
gcloud services enable \
  bigquery.googleapis.com \
  dataform.googleapis.com \
  dataplex.googleapis.com \
  datacatalog.googleapis.com \
  aiplatform.googleapis.com \
  secretmanager.googleapis.com
```

### 2. Create BigQuery datasets

```bash
for DATASET in raw staging marts; do
  bq mk --dataset --location=US ${PROJECT_ID}:${DATASET}
done
```

### 3. Copy source tables

```bash
for TABLE in orders order_items users products; do
  bq cp bigquery-public-data:thelook_ecommerce.${TABLE} ${PROJECT_ID}:raw.${TABLE}
done
```

### 4. Configure IAM

```bash
bash iam/setup.sh
```

### 5. Configure Dataform

- Create repository in Dataform console pointing to this GitHub repo
- Create workspace `dev`
- Run all actions from the workspace

### 6. Configure Dataplex

```bash
bash dataplex/setup.sh
```

### 7. Create Business Glossary

```bash
bash glossary/terms.sh

```

## Key Concepts Demonstrated

- **Three-layer architecture** (raw → staging → marts) with clear separation of concerns
- **Data governance** with lake management, zones, and automated quality scans
- **Column and row-level security** using GCP native tools
- **CI/CD for data** with Dataform connected to GitHub
- **Semantic layer** with Business Glossary designed for AI agent consumption
- **Agentic architecture** with Vertex AI querying BigQuery via Remote Functions (Phase 4)

## Phase Roadmap

- [x] Phase 1 — BigQuery architecture + IAM + Security
- [x] Phase 2 — Dataform models + assertions + Git integration
- [x] Phase 3 — Dataplex governance + Business Glossary
- [ ] Phase 4 — Vertex AI agentic layer
