-- Remote model over Gemini 2.5 Flash via Vertex AI
-- Connection: data-engineer-project-496417.US.vertex-ai-connection
-- Run once to create or update the model

CREATE OR REPLACE MODEL `data-engineer-project-496417.marts.gemini_model`
REMOTE WITH CONNECTION DEFAULT
OPTIONS (endpoint = 'gemini-2.5-flash');