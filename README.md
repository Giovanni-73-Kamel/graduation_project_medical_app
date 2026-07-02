# Medical App V3

Medical App V3 is a full-stack health monitoring system that combines a Flutter mobile app, a FastAPI backend, PostgreSQL storage, ESP32 ECG/PPG hardware firmware, and local AI models for ECG, heartbeat morphology, and blood pressure analysis.

The AI output is decision support only. It is not a final medical diagnosis and should be reviewed by qualified medical professionals.

## What The Project Includes

- Flutter app for patients and doctors.
- Authentication and profile management.
- Doctor/patient workflows for appointments and patient lists.
- Contacts, reminders, medical records, prescriptions, lab results, clinics, and medications.
- AI health chat endpoint backed by Gemini when configured.
- ESP32 firmware for ECG and PPG capture.
- FastAPI ECG/PPG ingest API for hardware readings.
- PostgreSQL database with Alembic migrations.
- Signal processing and local Keras model inference.
- Dockerfile for deploying the backend and AI models together.

## System Architecture

```text
ESP32 ECG/PPG hardware
  -> POST /api/readings
  -> FastAPI backend
  -> PostgreSQL devices/sessions/raw_readings
  -> Signal processing + AI model inference
  -> analysis_results + clinical_alerts
  -> Flutter app charts, metrics, alerts, and AI results
```

The hardware never calls the AI models directly. It only sends sensor batches to the backend. The backend validates and stores the readings, runs the analysis pipeline, saves the results, and exposes them to the Flutter app.

## Repository Layout

```text
.
+-- AI models/                         # Local Keras model artifacts and scalers
+-- Backend-bisho/                     # FastAPI backend
|   +-- app/                           # App config, DB, models, schemas, services
|   +-- DB/versions/                   # Alembic migration files
|   +-- routers/                       # API route modules
|   +-- tests/                         # Backend tests
|   +-- .env.example                   # Backend environment template
|   +-- requirements.txt               # Python dependencies
+-- docs/                              # Sample payload and Postman collection
+-- hardware/                          # ESP32 firmware and config template
|   +-- ECG_PPG_HR_SPO2/
+-- images/                            # Flutter image assets
+-- lib/                               # Flutter source code
|   +-- auth_pages/
|   +-- home_pages/
|   +-- screens/
|   +-- services/
|   +-- models/
+-- test/                              # Flutter tests
+-- Dockerfile                         # Backend + AI model Docker image
+-- pubspec.yaml                       # Flutter dependencies
```

## Main Technologies

- Flutter / Dart
- FastAPI
- PostgreSQL
- SQLAlchemy
- Alembic
- TensorFlow / Keras
- NumPy and scikit-learn
- ESP32 Arduino firmware
- MAX30105 PPG sensor
- AD8232-style ECG analog front end
- Docker

## Backend Setup

From the repository root:

```powershell
cd Backend-bisho
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
```

Edit `Backend-bisho/.env` with your local values.

Important backend variables:

```env
DATABASE_HOSTNAME=localhost
DATABASE_PORT=5432
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=postgres
DATABASE_NAME=medical_app
# DATABASE_URL=postgresql://postgres:postgres@localhost:5432/medical_app

SECRET_KEY=replace-with-a-long-random-secret

DEVICE_INGEST_TOKEN=

GEMINI_API_KEY=
GEMINI_MODEL_NAME=

ECG_MODEL_DIR=../AI models/ecg_classifier_v31_deployment
MORPHOLOGY_MODEL_DIR=../AI models/Morphological Heartbeat Arrhythmia Classifier
BP_MODEL_DIR=../AI models/BP_Model_Vital_15_Meta

AUTO_ANALYZE_ON_UPLOAD=false
```

Run database migrations:

```powershell
alembic upgrade head
```

Start the backend:

```powershell
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open Swagger docs:

```text
http://127.0.0.1:8000/docs
```

If another device on the same WiFi needs to reach the backend, use your computer LAN IP:

```text
http://YOUR_PC_LAN_IP:8000/docs
```

## Backend API Areas

General app endpoints:

- `POST /login/`
- `POST /users/`
- `GET /users/me`
- `PUT/PATCH /users/me`
- `/patients`
- `/doctors`
- `/appointments`
- `/contacts`
- `/reminders`
- `/medical-records`
- `/prescriptions`
- `/lab-results`
- `/clinics`
- `/medications`
- `/admin`
- `POST /chat`

ECG/PPG and AI pipeline endpoints:

- `POST /api/sessions`
- `POST /api/readings`
- `GET /api/sessions`
- `GET /api/sessions/{session_id}`
- `GET /api/sessions/{session_id}/readings`
- `POST /api/analyze/{session_id}`
- `GET /api/sessions/{session_id}/analysis`
- `GET /api/devices`
- `POST /api/devices`
- `PATCH /api/devices/{device_id}/assign`
- `GET /api/alerts`
- `PATCH /api/alerts/{alert_id}/resolve`
- `GET /api/ai/models`
- `GET /api/analysis-worker/status`

## ECG/PPG Hardware Flow

The firmware is in:

```text
hardware/ECG_PPG_HR_SPO2/ECG_PPG_HR_SPO2.ino
```

It samples ECG and PPG, groups readings into batches, then sends JSON to:

```text
POST /api/readings
```

Each upload includes:

- `device_id`
- `session_id`
- `timestamp`
- `sampling_rate`
- `ecg`
- `ppg`
- `battery`
- `status`
- sensor metadata such as finger detection, lead status, IR quality, SpO2 estimate, and firmware version

The backend stores the reading in `raw_readings`, creates the device/session if needed, and returns device commands such as:

- `continue`
- `check_sensor_contact`
- `low_battery_warning`
- `retry_capture`
- `clinical_review`

## Hardware Setup

1. Install Arduino IDE.
2. Install ESP32 board support.
3. Install the SparkFun `MAX30105` library.
4. Copy the config template:

```powershell
Copy-Item hardware\config.example.h hardware\ECG_PPG_HR_SPO2\config.h
```

5. Edit `hardware/ECG_PPG_HR_SPO2/config.h`:

```cpp
#define WIFI_SSID "your-wifi-name"
#define WIFI_PASSWORD "your-wifi-password"

#define BACKEND_READINGS_URL "http://YOUR_BACKEND_IP:8000/api/readings"
#define DEVICE_ID "device_001"
#define SESSION_ID "session_001"
#define DEVICE_API_KEY ""
```

If `DEVICE_INGEST_TOKEN` is set in the backend `.env`, `DEVICE_API_KEY` must match it.

6. Open `hardware/ECG_PPG_HR_SPO2/ECG_PPG_HR_SPO2.ino` in Arduino IDE.
7. Select the ESP32 board and port.
8. Upload the firmware.
9. Open Serial Monitor at `115200` baud to watch WiFi and upload status.

## Testing Hardware From Swagger

After the ESP32 is running, open:

```text
http://YOUR_BACKEND_IP:8000/docs
```

Check that sessions are arriving:

```text
GET /api/sessions
```

Then copy a `session_id` and check readings:

```text
GET /api/sessions/{session_id}/readings
```

If the hardware is sending correctly, you should see ECG/PPG arrays, `sample_count`, status, battery, and metadata.

To run the AI pipeline:

```text
POST /api/analyze/{session_id}
```

Then view saved results:

```text
GET /api/sessions/{session_id}/analysis
```

## AI Model Pipeline

The backend uses `Backend-bisho/app/services/ai_inference.py`.

The pipeline runs:

1. Signal cleanup and quality checks.
2. ECG and PPG metric extraction.
3. Recent hardware SpO2 estimate extraction from metadata.
4. ECG arrhythmia model.
5. Heartbeat morphology model.
6. Blood pressure model.
7. Alert and summary generation.

Model directories:

```text
AI models/ecg_classifier_v31_deployment
AI models/Morphological Heartbeat Arrhythmia Classifier
AI models/BP_Model_Vital_15_Meta
```

Model requirements:

- ECG arrhythmia model needs enough ECG samples. The backend expects at least `1250` ECG samples for the record-level classifier.
- Morphology model needs beat-centered ECG windows.
- Blood pressure model needs usable PPG peaks and assigned patient height/weight, because it builds metadata from weight, height, and BMI.

If a model cannot run, the backend still returns signal metrics and marks that model result as unavailable with a reason.

## Flutter Setup

Install Flutter dependencies:

```powershell
flutter pub get
```

Run the app with an explicit backend URL:

```powershell
flutter run --dart-define=BACKEND_BASE_URL=http://127.0.0.1:8000
```

For Android physical devices, use the backend computer LAN IP:

```powershell
flutter run --dart-define=BACKEND_BASE_URL=http://YOUR_PC_LAN_IP:8000
```

For an EC2 backend:

```powershell
flutter run --dart-define=BACKEND_BASE_URL=http://YOUR_EC2_PUBLIC_IP:8000
```

Production should use HTTPS:

```powershell
flutter run --dart-define=BACKEND_BASE_URL=https://api.your-domain.com
```

Default backend URLs are defined in:

```text
lib/config/app_config.dart
```

## Flutter Features

- Login and signup.
- Patient and doctor screens.
- Doctor selection.
- Appointments and patient details.
- Contacts and reminders.
- Profile and body metrics.
- ECG/PPG session list.
- ECG and PPG charts.
- AI analysis results.
- Signal quality and clinical alerts.
- AI chatbot UI.

## Docker Deployment

The root `Dockerfile` packages:

- `Backend-bisho`
- Python dependencies
- AI model folders from `AI models`

Build:

```bash
docker build -t medical-backend-ai .
```

Run:

```bash
docker run -d \
  --name medical-backend \
  --restart unless-stopped \
  -p 8000:8000 \
  -e DATABASE_URL=postgresql://user:password@host:5432/medical_app \
  -e SECRET_KEY=replace-with-a-long-random-secret \
  -e DEVICE_INGEST_TOKEN=replace-with-device-token \
  -e CORS_ORIGINS=http://localhost:3000 \
  -e RUN_MIGRATIONS=true \
  medical-backend-ai
```

Swagger:

```text
http://127.0.0.1:8000/docs
```

## EC2 Hardware Deployment Notes

For temporary testing from ESP32 to EC2:

```cpp
#define BACKEND_READINGS_URL "http://YOUR_EC2_PUBLIC_IP:8000/api/readings"
```

EC2 requirements:

- Backend must listen on `0.0.0.0`.
- Docker or Uvicorn must expose port `8000`.
- EC2 security group must allow inbound TCP `8000` for testing.
- `DEVICE_API_KEY` in firmware must match backend `DEVICE_INGEST_TOKEN` if token auth is enabled.

For production, prefer:

```cpp
#define BACKEND_READINGS_URL "https://api.your-domain.com/api/readings"
```

Use a domain, HTTPS, and either Nginx or an AWS Load Balancer in front of the backend.

## Database Tables Used By The ECG Pipeline

- `devices`: device identity, patient assignment, firmware, metadata, last seen time.
- `sessions`: monitoring sessions by `session_id`, device, patient, sampling rate, and status.
- `raw_readings`: uploaded ECG/PPG samples and capture metadata.
- `analysis_results`: metrics, signal quality, predictions, alerts, and disclaimer.
- `clinical_alerts`: alerts generated from signal quality or AI results.

## Tests

Backend tests:

```powershell
cd Backend-bisho
pytest
```

Flutter tests:

```powershell
flutter test
```

Useful backend test files:

```text
Backend-bisho/tests/test_ecg_pipeline_api.py
Backend-bisho/tests/test_ai_integration.py
Backend-bisho/tests/test_signal_processing.py
Backend-bisho/tests/test_user_endpoints.py
```

## Quick End-To-End Check

1. Start PostgreSQL.
2. Configure `Backend-bisho/.env`.
3. Run:

```powershell
cd Backend-bisho
alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

4. Open Swagger:

```text
http://127.0.0.1:8000/docs
```

5. Send a sample reading with:

```text
POST /api/readings
```

You can use:

```text
docs/sample_reading_payload.json
```

6. Verify:

```text
GET /api/sessions
GET /api/sessions/{session_id}/readings
```

7. Run:

```text
POST /api/analyze/{session_id}
```

8. Open Flutter and check the My Heart screen.

## Troubleshooting

If Swagger does not open:

- Check that the backend is running.
- Check the port is `8000`.
- On LAN/EC2, make sure the backend uses `--host 0.0.0.0`.
- Check firewall or EC2 security group rules.

If hardware readings do not appear:

- Confirm `BACKEND_READINGS_URL` points to `/api/readings`.
- Confirm ESP32 and backend are on reachable networks.
- Confirm `DEVICE_API_KEY` matches `DEVICE_INGEST_TOKEN`.
- Watch ESP32 Serial Monitor for HTTP status codes.
- Check `GET /api/sessions` and `GET /api/sessions/{session_id}/readings`.

If analysis fails:

- Confirm the session has readings.
- Check the latest reading status. `no_finger` or `ppg_sensor_off` can block analysis.
- Confirm there are enough ECG/PPG samples.
- Confirm TensorFlow can load the model files.
- Confirm patient height and weight are set before using the blood pressure model.

If Flutter cannot connect:

- Pass `--dart-define=BACKEND_BASE_URL=...`.
- Use LAN IP for physical phones.
- Use HTTPS/domain for production deployments.
- Check backend CORS settings.

## Security Notes

Do not commit:

- `.env`
- WiFi credentials
- database passwords
- JWT secret keys
- Gemini API keys
- production device ingest tokens
- private deployment files

Keep `DEVICE_INGEST_TOKEN` enabled for deployed backends so random clients cannot upload fake device readings.

## Medical Disclaimer

This project is for educational and decision-support purposes. The AI models and signal processing results are not a substitute for professional medical diagnosis, treatment, or emergency care.
