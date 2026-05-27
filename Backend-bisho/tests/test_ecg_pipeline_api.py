from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app


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
    session_response = client.post("/api/sessions", json=session_payload)
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
        },
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
    assert "models" in body["predictions"]


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
