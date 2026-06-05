# Instalar dependencias
pip install google-cloud-bigquery google-cloud-aiplatform vertexai --break-system-packages

# Autenticarse con Application Default Credentials
gcloud auth application-default login

# Correr el agente
cd ~ && python vertex_ai/agent.py