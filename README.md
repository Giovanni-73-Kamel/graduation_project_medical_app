# Medical App V3

Full-stack medical monitoring app with ESP ECG/PPG firmware, FastAPI backend, PostgreSQL persistence, AI-assisted signal analysis, and Flutter visualization.

AI results are decision-support only, not a final medical diagnosis.

## Architecture

Hardware collects ECG from an analog front end and PPG from MAX30105, batches samples, and posts JSON to the backend. FastAPI validates and stores raw readings in PostgreSQL, runs signal processing plus the optional Keras ECG classifier, stores analysis results, and exposes `/api/*` endpoints. Flutter fetches sessions, readings, metrics, alerts, and AI results for chart-based review.

Flow:

```text
ESP ECG/PPG firmware
  -> POST /api/readings
  -> FastAPI validation
  -> PostgreSQL raw_readings
  -> AI/signal analysis
  -> analysis_results
  -> Flutter sessions, charts, metrics, alerts
```

## Repository Layout

- `hardware/ECG_PPG_HR_SPO2.ino`: ESP firmware for sampling and upload.
- `hardware/config.example.h`: local firmware configuration template.
- `Backend-bisho/app`: FastAPI app, models, schemas, config, DB session.
- `Backend-bisho/routers/ecg_pipeline.py`: ECG/PPG REST API.
- `Backend-bisho/app/services`: signal processing and AI inference adapter.
- `Backend-bisho/DB/versions`: Alembic migrations.
- `AI models`: Keras model/scaler/config artifacts.
- `lib`: Flutter app, API service, ECG/PPG UI and models.
- `docs`: sample payload and Postman collection.

## Backend Setup

```powershell
cd Backend-bisho
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
```

Edit `.env` with PostgreSQL credentials and optional model settings.

Run migrations:

```powershell
alembic upgrade head
```

Start API:

```powershell
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Database

Required ECG/PPG tables:

- `devices`: unique device identity, metadata, last seen timestamp.
- `sessions`: logical monitoring sessions by `session_id`, `device_id`, sampling rate, status.
- `raw_readings`: uploaded ECG/PPG arrays, timestamp, battery, sample count.
- `analysis_results`: metrics, signal quality, AI predictions, alerts, disclaimer.

Indexes are added on `device_id`, `session_id`, and `timestamp`. `raw_readings` has a unique `(session_id, timestamp)` constraint to prevent duplicate packet corruption.

## AI Model Setup

Default ECG model directory:

```text
AI models/ecg_classifier_v31_deployment
```

The backend adapter loads `ecg_classifier_v31.py`, `.keras`, `scaler.pkl`, and `config.json` when TensorFlow/scikit-learn are installed. If unavailable, the API still returns deterministic signal-derived metrics and marks the model as unavailable in `predictions.ecg_classifier`.

Configuration:

```env
ECG_MODEL_DIR=../AI models/ecg_classifier_v31_deployment
ECG_MODEL_ENABLED=true
AUTO_ANALYZE_ON_UPLOAD=true
AUTO_ANALYZE_MIN_SAMPLES=100
```

## API Summary

Create session:

```http
POST /api/sessions
```

Upload reading:

```http
POST /api/readings
```

Run analysis:

```http
POST /api/analyze/{session_id}
```

Fetch data:

```http
GET /api/sessions
GET /api/sessions/{session_id}
GET /api/sessions/{session_id}/readings
GET /api/sessions/{session_id}/analysis
```

Sample reading payload:

```json
{
  "device_id": "device_001",
  "session_id": "session_123",
  "timestamp": "2026-05-13T10:30:00Z",
  "sampling_rate": 250,
  "ecg": [0.12, 0.15, 0.18],
  "ppg": [520, 525, 531],
  "battery": 90,
  "status": "active"
}
```

cURL:

```bash
curl -X POST http://127.0.0.1:8000/api/sessions \
  -H "Content-Type: application/json" \
  -d "{\"device_id\":\"device_001\",\"session_id\":\"session_123\",\"sampling_rate\":250,\"status\":\"active\"}"

curl -X POST http://127.0.0.1:8000/api/readings \
  -H "Content-Type: application/json" \
  -d @../docs/sample_reading_payload.json

curl -X POST http://127.0.0.1:8000/api/analyze/session_123
```

Postman collection: `docs/postman_ecg_pipeline_collection.json`.

## Flutter Setup

```powershell
flutter pub get
flutter run --dart-define=BACKEND_BASE_URL=http://127.0.0.1:8000
```

Defaults:

- Android emulator: `http://10.0.2.2:8000`
- Web: `http://localhost:8000`
- Desktop/iOS simulator: `http://127.0.0.1:8000`

Flutter ECG/PPG features:

- Sessions list.
- Session detail view.
- ECG and PPG time-series charts.
- AI metrics and conclusions.
- Alerts/warnings.
- Loading, retry, error, and empty states.

## Hardware Upload

1. Install Arduino ESP32 board support.
2. Install the SparkFun `MAX30105` library.
3. Copy `hardware/config.example.h` to `hardware/config.h`.
4. Set Wi-Fi, backend URL, device ID, session ID, and pins.
5. Open `hardware/ECG_PPG_HR_SPO2.ino` in Arduino IDE.
6. Select the ESP32 board and upload.

Firmware posts batches to:

```text
BACKEND_READINGS_URL=http://<backend-ip>:8000/api/readings
```

## Testing

Backend:

```powershell
cd Backend-bisho
pytest
```

Flutter:

```powershell
flutter test
```

End-to-end quick check:

1. Start PostgreSQL.
2. Run `alembic upgrade head`.
3. Start FastAPI on port `8000`.
4. POST the sample session and reading payload.
5. POST `/api/analyze/session_123`.
6. Start Flutter with `BACKEND_BASE_URL`.
7. Open `My Heart` and refresh sessions.

## Environment Variables

Backend variables are documented in `Backend-bisho/.env.example`. Flutter uses `--dart-define=BACKEND_BASE_URL=...`. Hardware uses `hardware/config.h`, which is intentionally ignored by Git.

Never commit Wi-Fi credentials, API keys, database URLs, or local model paths with secrets.
