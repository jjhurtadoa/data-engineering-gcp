-- ============================================================
-- Vertex AI + BigQuery ML — Agentic Layer Queries
-- Model: marts.gemini_model (gemini-2.5-flash)
-- ============================================================

-- 1. Model smoke test
-- Verifies the remote model is responding correctly
SELECT ml_generate_text_result
FROM ML.GENERATE_TEXT(
  MODEL `data-engineer-project-496417.marts.gemini_model`,
  (SELECT 'Responde en español: ¿Qué es el revenue en un ecommerce?' AS prompt),
  STRUCT(0.2 AS temperature, 1024 AS max_output_tokens)
);

-- 2. Text-to-SQL
-- Uses Business Glossary as context to generate SQL from natural language
SELECT ml_generate_text_result
FROM ML.GENERATE_TEXT(
  MODEL `data-engineer-project-496417.marts.gemini_model`,
  (SELECT CONCAT(
    'Eres un analista de datos experto en BigQuery. Usa estas definiciones:\n',
    '- Revenue: SUM(sale_price) WHERE status = Complete\n',
    '- Margin: sale_price - cost\n',
    '- Active User: user_id con al menos 1 orden Complete en últimos 90 días\n\n',
    'Tabla: `data-engineer-project-496417.marts.fct_orders`\n',
    'Columnas: order_id, user_id, status, sale_price, cost, margin, country, ',
    'gender, age_group, traffic_source, category, brand, order_date\n\n',
    'Genera SOLO el SQL para: ¿Cuál es el revenue total por país?'
  ) AS prompt),
  STRUCT(0.1 AS temperature, 1024 AS max_output_tokens)
);

-- 3. Agentic analysis
-- Queries real BigQuery data and LLM generates business insights
SELECT ml_generate_text_result
FROM ML.GENERATE_TEXT(
  MODEL `data-engineer-project-496417.marts.gemini_model`,
  (
    SELECT CONCAT(
      'Eres un analista de negocio. Analiza estos datos de revenue por país y dame ',
      'un resumen ejecutivo en español con los 3 insights más importantes:\n\n',
      STRING_AGG(
        CONCAT(country, ': $', CAST(ROUND(revenue, 2) AS STRING)),
        '\n'
      )
    ) AS prompt
    FROM (
      SELECT
        country,
        SUM(sale_price) AS revenue
      FROM `data-engineer-project-496417.marts.fct_orders`
      WHERE status = 'Complete'
      GROUP BY country
      ORDER BY revenue DESC
      LIMIT 10
    )
  ),
  STRUCT(0.3 AS temperature, 1024 AS max_output_tokens)
);