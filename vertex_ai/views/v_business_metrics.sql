-- Semantic view that encapsulates Business Glossary definitions
-- This is the entry point for the agentic layer
-- Revenue, Margin, and Active User are pre-calculated per glossary definitions

CREATE OR REPLACE VIEW `data-engineer-project-496417.marts.v_business_metrics` AS
SELECT
  -- Identifiers
  order_id,
  user_id,
  product_id,
  order_item_id,

  -- Dimensions
  country,
  gender,
  age_group,
  traffic_source,
  category,
  department,
  brand,
  order_date,
  EXTRACT(YEAR FROM order_date)  AS order_year,
  EXTRACT(MONTH FROM order_date) AS order_month,

  -- Status
  status,
  CASE WHEN status = 'Complete' THEN 1 ELSE 0 END AS is_complete,

  -- Revenue (Business Glossary: solo ordenes Complete)
  CASE WHEN status = 'Complete' THEN sale_price ELSE 0 END AS revenue,

  -- Margin (Business Glossary: sale_price - cost)
  CASE WHEN status = 'Complete' THEN margin ELSE 0 END AS margin,
  CASE WHEN status = 'Complete' THEN
    ROUND(margin / NULLIF(sale_price, 0) * 100, 2)
  ELSE 0 END AS margin_pct,

  -- Fulfillment
  days_to_ship,
  days_to_deliver

FROM `data-engineer-project-496417.marts.fct_orders`;