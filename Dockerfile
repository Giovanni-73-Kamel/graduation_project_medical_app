# syntax=docker/dockerfile:1

FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_HOME=/app \
    PORT=8000 \
    ECG_MODEL_DIR=/app/ai_models/ecg_classifier_v31_deployment \
    MORPHOLOGY_MODEL_DIR="/app/ai_models/Morphological Heartbeat Arrhythmia Classifier" \
    BP_MODEL_DIR=/app/ai_models/BP_Model_Vital_15_Meta

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl libgomp1 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /app/ai_models

COPY Backend-bisho/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r /tmp/requirements.txt

COPY Backend-bisho /app
COPY ["AI models", "/app/ai_models"]

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS http://127.0.0.1:${PORT}/ || exit 1

CMD ["sh", "-c", "if [ \"$RUN_MIGRATIONS\" = \"true\" ]; then alembic upgrade head; fi; exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
