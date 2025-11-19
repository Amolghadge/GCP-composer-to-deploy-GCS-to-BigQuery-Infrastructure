# Dockerfile for local development and testing
FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy project files
COPY requirements.txt .
COPY dags/ ./dags/
COPY terraform/ ./terraform/

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Set environment variables for Airflow
ENV AIRFLOW_HOME=/app/airflow
ENV AIRFLOW__CORE__DAGS_FOLDER=/app/dags
ENV AIRFLOW__CORE__LOAD_EXAMPLES=False
ENV PYTHONUNBUFFERED=1

# Create directories
RUN mkdir -p /app/airflow/logs /app/airflow/plugins

# Initialize Airflow database
RUN airflow db init || true

# Default command
CMD ["python", "-m", "py_compile", "dags/gcs_to_bigquery_dag.py"]
