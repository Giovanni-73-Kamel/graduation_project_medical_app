from __future__ import annotations

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
import app.models as models
import app.utils as utils
from routers import oauth2


def _client_with_seeded_users():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    testing_session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    db = testing_session_local()
    doctor = models.User(
        username="doctor",
        email="doctor@example.com",
        password=utils.hash("password"),
        role="doctor",
        phone_number="123",
        date_of_birth="1980-01-01",
        is_registered=True,
    )
    patient = models.User(
        username="patient",
        email="patient@example.com",
        password=utils.hash("password"),
        role="patient",
        phone_number="555",
        date_of_birth="1990-01-01",
        is_registered=True,
    )
    db.add_all([doctor, patient])
    db.commit()
    db.refresh(doctor)
    db.refresh(patient)
    db.close()

    def override_get_db():
        session = testing_session_local()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[oauth2.get_current_user] = lambda: patient
    return TestClient(app), testing_session_local, patient, doctor


def test_patch_users_me_updates_profile_and_doctor_assignment():
    client, session_factory, patient, doctor = _client_with_seeded_users()
    try:
        response = client.patch(
            "/users/me",
            json={
                "phone_number": "777",
                "doctor_id": doctor.id,
            },
        )

        assert response.status_code == 200
        body = response.json()
        assert body["phone_number"] == "777"

        db = session_factory()
        updated_patient = db.query(models.User).filter(models.User.id == patient.id).first()
        assert updated_patient.doc_id == doctor.id
        db.close()
    finally:
        app.dependency_overrides.clear()
