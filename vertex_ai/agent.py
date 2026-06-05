"""
agent.py — Agentic layer for TheLook Analytics
================================================
Translates natural language questions into BigQuery SQL using Gemini,
executes the query, and returns a business-friendly answer.

Usage:
    python vertex_ai/agent.py

Requirements:
    pip install google-cloud-bigquery google-cloud-aiplatform vertexai
"""

import vertexai
from vertexai.generative_models import GenerativeModel
from google.cloud import bigquery

# ── Configuration ─────────────────────────────────────────────────────────────

PROJECT_ID = "data-engineer-project-496417"
LOCATION   = "us-central1"
MODEL_ID   = "gemini-2.5-flash"

# Business Glossary context — mirrors the Dataplex glossary definitions
BUSINESS_GLOSSARY = """
You are an expert data analyst for an e-commerce company.
Use these official business definitions:

- Revenue: SUM(sale_price) for order_items WHERE status = 'Complete'.
  Never include Cancelled, Returned, Processing or Shipped orders.
- Margin: sale_price - cost per item. Positive = profit, negative = loss.
- Margin %: (margin / sale_price) * 100
- Active User: user_id with at least 1 Complete order in the last 90 days.
- Churn: user_id with at least 1 Complete order but no orders in the last 90 days.

The main table is:
  `data-engineer-project-496417.marts.v_business_metrics`

Available columns:
  order_id, user_id, product_id, order_item_id,
  country, gender, age_group, traffic_source,
  category, department, brand,
  order_date, order_year, order_month,
  status, is_complete,
  revenue, margin, margin_pct,
  days_to_ship, days_to_deliver

Rules:
- Always use the v_business_metrics view, never fct_orders directly.
- revenue and margin columns already filter for Complete orders — do not add WHERE status = 'Complete' when using them.
- Always use standard BigQuery SQL (GoogleSQL).
- Return ONLY the SQL query, no explanations, no markdown, no backticks.
"""

ANSWER_PROMPT = """
You are a business analyst presenting results to a non-technical executive.
Given this data from our e-commerce analytics platform:

{data}

Answer this question in Spanish in 2-3 sentences, highlighting the most important insight:
{question}

Be specific with numbers. Use $ for revenue figures.
"""

# ── Core functions ─────────────────────────────────────────────────────────────

def generate_sql(question: str, model: GenerativeModel) -> str:
    """Use Gemini to translate a natural language question into BigQuery SQL."""
    prompt = f"{BUSINESS_GLOSSARY}\n\nQuestion: {question}\n\nSQL:"
    response = model.generate_content(
        prompt,
        generation_config={"temperature": 0.1, "max_output_tokens": 1024}
    )
    sql = response.text.strip()
    # Clean up any accidental markdown fences
    sql = sql.replace("```sql", "").replace("```", "").strip()
    return sql


def run_query(sql: str, bq_client: bigquery.Client) -> list[dict]:
    """Execute a BigQuery SQL query and return results as a list of dicts."""
    query_job = bq_client.query(sql)
    results = query_job.result()
    return [dict(row) for row in results]


def format_results(rows: list[dict]) -> str:
    """Format query results as a readable string for the LLM."""
    if not rows:
        return "No data found."
    lines = []
    for row in rows:
        line = ", ".join(f"{k}: {v}" for k, v in row.items())
        lines.append(line)
    return "\n".join(lines)


def generate_answer(question: str, data: str, model: GenerativeModel) -> str:
    """Use Gemini to generate a business-friendly answer from the query results."""
    prompt = ANSWER_PROMPT.format(data=data, question=question)
    response = model.generate_content(
        prompt,
        generation_config={"temperature": 0.3, "max_output_tokens": 512}
    )
    return response.text.strip()


def ask(question: str, model: GenerativeModel, bq_client: bigquery.Client) -> None:
    """Full agentic pipeline: question → SQL → execute → answer."""
    print(f"\n{'='*60}")
    print(f"Question: {question}")
    print('='*60)

    # Step 1: Generate SQL
    print("\n[1] Generating SQL...")
    sql = generate_sql(question, model)
    print(f"Generated SQL:\n{sql}")

    # Step 2: Execute SQL
    print("\n[2] Executing query in BigQuery...")
    try:
        rows = run_query(sql, bq_client)
        print(f"Rows returned: {len(rows)}")
    except Exception as e:
        print(f"Query error: {e}")
        return

    # Step 3: Generate answer
    print("\n[3] Generating business answer...")
    data_str = format_results(rows[:20])  # limit to 20 rows for context
    answer = generate_answer(question, data_str, model)

    print(f"\nAnswer:\n{answer}")


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    # Initialize clients
    vertexai.init(project=PROJECT_ID, location=LOCATION)
    model     = GenerativeModel(MODEL_ID)
    bq_client = bigquery.Client(project=PROJECT_ID)

    # Demo questions — these showcase the Business Glossary in action
    questions = [
        "¿Cuál es el revenue total por país en el último año?",
        "¿Cuáles son las 5 categorías de productos con mayor margen promedio?",
        "¿Cuál es el canal de adquisición (traffic_source) que genera más revenue?",
        "¿Cuántos días tarda en promedio el envío por país?",
    ]

    for question in questions:
        ask(question, model, bq_client)

    print(f"\n{'='*60}")
    print("Done. All questions processed.")


if __name__ == "__main__":
    main()