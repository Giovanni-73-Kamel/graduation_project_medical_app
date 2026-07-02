from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models as models
from app.database import Base, get_db
from app.main import app
from app.config import settings
from app.services.ai_inference import ECG_RECORD_INPUT_SAMPLES


def _device_headers():
    return {"X-Device-Token": settings.device_ingest_token} if settings.device_ingest_token else {}


@pytest.fixture()
def client():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    testing_session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    def override_get_db():
        db = testing_session_local()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.clear()


def test_upload_reading_and_analyze_end_to_end(client):
    session_payload = {
        "device_id": "device_001",
        "session_id": "session_api_test",
        "sampling_rate": 250,
        "status": "active",
    }
    headers = _device_headers()
    session_response = client.post("/api/sessions", json=session_payload, headers=headers)
    assert session_response.status_code == 201

    ecg = [0.0] * 150
    ppg = [10.0] * 150
    for index in (25, 75, 125):
        ecg[index] = 1.3
        ppg[index] = 30.0

    reading_response = client.post(
        "/api/readings",
        json={
            "device_id": "device_001",
            "session_id": "session_api_test",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sampling_rate": 250,
            "ecg": ecg,
            "ppg": ppg,
            "battery": 90,
            "status": "active",
            "metadata": {
                "finger_detected": True,
                "spo2_valid": True,
                "spo2_percent": 97.4,
            },
        },
        headers=headers,
    )
    assert reading_response.status_code == 201
    reading_body = reading_response.json()
    assert reading_body["sample_count"] == 150
    assert reading_body["commands"]

    readings_response = client.get("/api/sessions/session_api_test/readings")
    assert readings_response.status_code == 200
    assert len(readings_response.json()) == 1

    analysis_response = client.post("/api/analyze/session_api_test")
    assert analysis_response.status_code == 201
    body = analysis_response.json()
    assert body["session_id"] == "session_api_test"
    assert body["disclaimer"] == "Decision-support only, not a final medical diagnosis."
    assert body["metrics"]["spo2_percent"] == 97.4
    assert "models" in body["predictions"]


def test_analysis_uses_device_patient_for_existing_unassigned_session(client, monkeypatch):
    patient_response = client.post(
        "/users/",
        json={
            "username": "bp-patient",
            "email": "bp-patient@example.com",
            "password": "password",
            "role": "patient",
            "phone_number": "555",
            "date_of_birth": "1990-01-01",
            "height": "175",
            "weight": "70",
            "doctor_name": "BP Doctor",
            "doctor_email": "bp-doctor@example.com",
            "doctor_phone": "123",
            "emergency_name": "BP Emergency",
            "emergency_email": "bp-emergency@example.com",
            "emergency_phone": "911",
        },
    )
    assert patient_response.status_code == 201
    patient_id = patient_response.json()["id"]

    session_response = client.post(
        "/api/sessions",
        json={
            "device_id": "bp_device",
            "session_id": "bp_late_assign_session",
            "sampling_rate": 250,
            "status": "active",
        },
        headers=_device_headers(),
    )
    assert session_response.status_code == 201
    assert session_response.json()["patient_id"] is None

    register_response = client.post(
        "/api/devices/register",
        json={"device_id": "bp_device", "patient_id": patient_id},
        headers=_device_headers(),
    )
    assert register_response.status_code == 200

    class FakeInferenceService:
        def analyze(self, readings, patient=None):
            model_available = patient is not None
            return {
                "model_name": "fake",
                "model_version": "test",
                "status": "completed" if model_available else "degraded",
                "metrics": {},
                "signal_quality": {},
                "predictions": {
                    "models": {
                        "blood_pressure_vital_meta": {
                            "status": "completed" if model_available else "unavailable",
                            "model_available": model_available,
                            "systolic_mmHg": 120.0 if model_available else None,
                            "diastolic_mmHg": 80.0 if model_available else None,
                        }
                    }
                },
                "alerts": [],
                "disclaimer": "Decision-support only, not a final medical diagnosis.",
            }

    monkeypatch.setattr(
        "routers.ecg_pipeline.get_inference_service",
        lambda: FakeInferenceService(),
    )

    reading_response = client.post(
        "/api/readings",
        json={
            "device_id": "bp_device",
            "session_id": "bp_late_assign_session",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sampling_rate": 250,
            "ecg": [0.0, 0.2, 0.0],
            "ppg": [18000.0, 18120.0, 17920.0],
            "battery": 90,
            "status": "active",
            "metadata": {
                "finger_detected": True,
                "ppg_sensor_ready": True,
            },
        },
        headers=_device_headers(),
    )
    assert reading_response.status_code == 201

    analysis_response = client.post("/api/analyze/bp_late_assign_session")
    assert analysis_response.status_code == 201
    body = analysis_response.json()
    bp_model = body["predictions"]["models"]["blood_pressure_vital_meta"]
    assert body["status"] == "completed"
    assert bp_model["status"] == "completed"
    assert bp_model["systolic_mmHg"] == 120.0

    session_after_response = client.get("/api/sessions/bp_late_assign_session")
    assert session_after_response.status_code == 200
    assert session_after_response.json()["patient_id"] == patient_id


def test_rejects_empty_signal_payload(client):
    response = client.post(
        "/api/readings",
        json={
            "device_id": "device_001",
            "session_id": "bad_payload",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sampling_rate": 250,
            "ecg": [],
            "ppg": [1.0],
            "battery": 90,
            "status": "active",
        },
        headers=_device_headers(),
    )

    assert response.status_code == 422


def test_rejects_unauthorized_device_reading_when_token_is_configured(client, monkeypatch):
    from app.config import settings

    monkeypatch.setattr(settings, "device_ingest_token", "device-secret", raising=False)

    response = client.post(
        "/api/readings",
        json={
            "device_id": "device_001",
            "session_id": "secure_session",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sampling_rate": 250,
            "ecg": [0.0, 1.0, 0.0],
            "ppg": [0.0, 1.0, 0.0],
            "battery": 90,
            "status": "active",
        },
    )

    assert response.status_code == 401


def test_no_finger_reading_returns_sensor_contact_command(client):
    response = client.post(
        "/api/readings",
        json={
            "device_id": "device_001",
            "session_id": "no_finger_session",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sampling_rate": 250,
            "ecg": [0.0, 0.1, 0.0],
            "ppg": [1200.0, 1210.0, 1195.0],
            "battery": 90,
            "status": "no_finger",
            "metadata": {
                "finger_detected": False,
                "finger_confidence": 0.0,
                "ir_mean": 1201.7,
                "finger_ir_threshold": 50000,
            },
        },
        headers=_device_headers(),
    )

    assert response.status_code == 201
    body = response.json()
    commands = response.json()["commands"]
    assert commands[0]["command_type"] == "check_sensor_contact"
    assert commands[0]["reason"] == "finger_not_detected"
    assert body["ppg"] == []
    assert body["sample_count"] == 3
    storage = body["metadata_json"]["storage"]
    assert storage["stored_ppg_samples"] == 0
    assert storage["dropped_signals"][0]["signal"] == "ppg"

    analysis_response = client.post("/api/analyze/no_finger_session")

    assert analysis_response.status_code == 400
    assert "Finger not detected" in analysis_response.json()["detail"]


def test_no_finger_status_is_overridden_when_ppg_signal_shows_contact(client):
    response = client.post(
        "/api/readings",
        json={
            "device_id": "device_001",
            "session_id": "ppg_contact_override_session",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sampling_rate": 250,
            "ecg": [0.0, 0.2, 0.0, 0.3],
            "ppg": [18000.0, 18120.0, 17920.0, 18200.0],
            "battery": 90,
            "status": "no_finger",
            "metadata": {
                "ppg_sensor_ready": True,
                "finger_detected": False,
                "ir_mean": 18060.0,
                "ir_ac_rms": 90.0,
                "ir_amplitude": 280.0,
                "finger_ir_threshold": 50000,
                "finger_ir_relaxed_threshold": 12000,
                "finger_ir_ac_threshold": 80,
                "finger_ir_amplitude_threshold": 150,
            },
        },
        headers=_device_headers(),
    )

    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "active"
    assert body["ppg"] == [18000.0, 18120.0, 17920.0, 18200.0]
    assert body["metadata_json"]["finger_detected"] is True
    assert body["metadata_json"]["finger_detected_backend_override"] is True
    assert body["metadata_json"]["hardware_status"] == "no_finger"
    assert body["metadata_json"]["storage"]["stored_ppg_samples"] == 4


def test_no_finger_high_dc_without_pulse_is_not_overridden(client):
    response = client.post(
        "/api/readings",
        json={
            "device_id": "device_001",
            "session_id": "high_dc_no_pulse_session",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sampling_rate": 250,
            "ecg": [0.0, 0.2, 0.0, 0.3],
            "ppg": [54000.0, 54018.0, 54010.0, 54022.0],
            "battery": 90,
            "status": "no_finger",
            "metadata": {
                "ppg_sensor_ready": True,
                "finger_detected": False,
                "ir_mean": 54012.5,
                "ir_ac_rms": 28.0,
                "ir_amplitude": 22.0,
                "finger_ir_threshold": 50000,
                "finger_ir_relaxed_threshold": 12000,
                "finger_ir_ac_threshold": 80,
                "finger_ir_amplitude_threshold": 150,
                "finger_allow_dc_only": False,
            },
        },
        headers=_device_headers(),
    )

    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "no_finger"
    assert body["ppg"] == []
    assert body["metadata_json"]["storage"]["stored_ppg_samples"] == 0


def test_ppg_sensor_off_returns_wiring_command(client):
    response = client.post(
        "/api/readings",
        json={
            "device_id": "device_001",
            "session_id": "ppg_off_session",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sampling_rate": 250,
            "ecg": [0.0, 0.1, 0.0],
            "ppg": [0.0, 0.0, 0.0],
            "battery": 90,
            "status": "ppg_sensor_off",
            "metadata": {
                "ppg_sensor_ready": False,
                "ppg_reinit_count": 3,
                "finger_detected": False,
            },
        },
        headers=_device_headers(),
    )

    assert response.status_code == 201
    body = response.json()
    commands = body["commands"]
    assert commands[0]["command_type"] == "check_sensor_contact"
    assert commands[0]["reason"] == "ppg_sensor_off"
    assert body["ppg"] == []
    assert body["metadata_json"]["storage"]["stored_ppg_samples"] == 0


def test_leads_off_reading_drops_flat_ecg_payload(client):
    response = client.post(
        "/api/readings",
        json={
            "device_id": "device_001",
            "session_id": "leads_off_session",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sampling_rate": 250,
            "ecg": [0.0, 0.0, 0.0],
            "ppg": [1200.0, 1250.0, 1190.0],
            "battery": 90,
            "status": "leads_off",
            "metadata": {
                "finger_detected": True,
                "ppg_sensor_ready": True,
            },
        },
        headers=_device_headers(),
    )

    assert response.status_code == 201
    body = response.json()
    assert body["ecg"] == []
    assert body["ppg"] == [1200.0, 1250.0, 1190.0]
    storage = body["metadata_json"]["storage"]
    assert storage["stored_ecg_samples"] == 0
    assert storage["stored_ppg_samples"] == 3

    analysis_response = client.post("/api/analyze/leads_off_session")

    assert analysis_response.status_code == 201
    analysis = analysis_response.json()
    assert analysis["status"] == "degraded"
    models = analysis["predictions"]["models"]
    assert models["ecg_arrhythmia_v31"]["status"] == "unavailable"
    assert models["morphology_heartbeat_v1"]["status"] == "unavailable"


def test_large_reading_payload_is_capped_with_storage_summary(client, monkeypatch):
    monkeypatch.setattr(settings, "max_raw_signal_samples_per_reading", 5, raising=False)
    signal = [float(index) for index in range(20)]
    response = client.post(
        "/api/readings",
        json={
            "device_id": "device_001",
            "session_id": "large_payload_session",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sampling_rate": 250,
            "ecg": signal,
            "ppg": [value + 1000.0 for value in signal],
            "battery": 90,
            "status": "active",
            "metadata": {
                "finger_detected": True,
                "ppg_sensor_ready": True,
            },
        },
        headers=_device_headers(),
    )

    assert response.status_code == 201
    body = response.json()
    assert len(body["ecg"]) == 5
    assert len(body["ppg"]) == 5
    assert body["sample_count"] == 20
    storage = body["metadata_json"]["storage"]
    assert storage["original_sample_count"] == 20
    assert storage["stored_ecg_samples"] == 5
    assert storage["stored_ppg_samples"] == 5
    assert {item["signal"] for item in storage["capped_signals"]} == {"ecg", "ppg"}


def test_auto_analysis_is_enqueued_after_reading_commit(client, monkeypatch):
    queued_sessions = []

    monkeypatch.setattr(settings, "auto_analyze_on_upload", True, raising=False)
    monkeypatch.setattr(settings, "auto_analyze_min_samples", 1, raising=False)
    monkeypatch.setattr(
        "routers.ecg_pipeline.enqueue_analysis",
        lambda session_id: queued_sessions.append(session_id) or True,
    )

    signal = [0.0] * ECG_RECORD_INPUT_SAMPLES
    ppg = [18000.0] * ECG_RECORD_INPUT_SAMPLES
    for index in range(40, ECG_RECORD_INPUT_SAMPLES, 250):
        signal[index] = 0.3
        ppg[index] = 18200.0

    response = client.post(
        "/api/readings",
        json={
            "device_id": "device_001",
            "session_id": "auto_queue_session",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sampling_rate": 250,
            "ecg": signal,
            "ppg": ppg,
            "battery": 90,
            "status": "active",
            "metadata": {
                "finger_detected": True,
                "ppg_sensor_ready": True,
            },
        },
        headers=_device_headers(),
    )

    assert response.status_code == 201
    assert queued_sessions == ["auto_queue_session"]


def test_delete_session_removes_readings_and_session(client):
    payload = {
        "device_id": "device_001",
        "session_id": "delete_one_session",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "sampling_rate": 250,
        "ecg": [0.0, 0.2, 0.0],
        "ppg": [18000.0, 18120.0, 17920.0],
        "battery": 90,
        "status": "active",
        "metadata": {
            "finger_detected": True,
            "ppg_sensor_ready": True,
        },
    }
    create_response = client.post("/api/readings", json=payload, headers=_device_headers())
    assert create_response.status_code == 201

    delete_response = client.delete("/api/sessions/delete_one_session")

    assert delete_response.status_code == 200
    assert delete_response.json()["deleted"]["sessions"] == 1
    assert delete_response.json()["deleted"]["raw_readings"] == 1
    assert client.get("/api/sessions/delete_one_session").status_code == 404
    assert client.get("/api/sessions/delete_one_session/readings").status_code == 404


def test_delete_all_sessions_clears_monitoring_records(client):
    for session_id in ("delete_all_a", "delete_all_b"):
        response = client.post(
            "/api/readings",
            json={
                "device_id": "device_001",
                "session_id": session_id,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "sampling_rate": 250,
                "ecg": [0.0, 0.2, 0.0],
                "ppg": [18000.0, 18120.0, 17920.0],
                "battery": 90,
                "status": "active",
                "metadata": {
                    "finger_detected": True,
                    "ppg_sensor_ready": True,
                },
            },
            headers=_device_headers(),
        )
        assert response.status_code == 201

    delete_response = client.delete("/api/sessions")

    assert delete_response.status_code == 200
    assert delete_response.json()["deleted"]["sessions"] == 2
    assert delete_response.json()["deleted"]["raw_readings"] == 2
    assert client.get("/api/sessions").json() == []


def test_compact_raw_readings_maintenance_dry_run_and_apply(monkeypatch):
    from app.maintenance import compact_raw_readings as compact_module

    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    testing_session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)
    monkeypatch.setattr(compact_module, "SessionLocal", testing_session_local)
    monkeypatch.setattr(settings, "compact_invalid_reading_signals", True, raising=False)
    monkeypatch.setattr(settings, "max_raw_signal_samples_per_reading", 1000, raising=False)

    db = testing_session_local()
    db.add(
        models.RawReading(
            device_id="device_001",
            session_id="old_bad_row",
            timestamp=datetime.now(timezone.utc),
            sampling_rate=250,
            ecg=[0.0, 0.2, 0.0],
            ppg=[1200.0, 1210.0, 1195.0],
            battery=90,
            status="no_finger",
            sample_count=3,
            metadata_json={"finger_detected": False},
        )
    )
    db.commit()
    db.close()

    dry_run = compact_module.compact_raw_readings(apply=False)
    assert dry_run.scanned == 1
    assert dry_run.changed == 1

    db = testing_session_local()
    unchanged = db.query(models.RawReading).filter_by(session_id="old_bad_row").one()
    assert unchanged.ppg == [1200.0, 1210.0, 1195.0]
    db.close()

    applied = compact_module.compact_raw_readings(apply=True)
    assert applied.scanned == 1
    assert applied.changed == 1
    assert applied.ppg_samples_removed == 3

    db = testing_session_local()
    compacted = db.query(models.RawReading).filter_by(session_id="old_bad_row").one()
    assert compacted.ppg == []
    assert compacted.metadata_json["storage"]["stored_ppg_samples"] == 0
    db.close()
