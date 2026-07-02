from __future__ import annotations

import logging
from datetime import datetime, timezone
import secrets
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

import app.models as models
import app.schemas as schemas
from app.config import settings
from app.database import get_db
from app.services.ai_inference import ECG_RECORD_INPUT_SAMPLES, get_inference_service
from app.services.analysis_worker import analysis_worker_state, enqueue_analysis
from app.services.reading_storage import prepare_reading_storage
from routers import oauth2

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["ECG/PPG Pipeline"])


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _require_device_token(request: Request) -> None:
    expected = settings.device_ingest_token.strip()
    if not expected:
        return
    provided = request.headers.get("X-Device-Token", "").strip()
    if not provided or not secrets.compare_digest(provided, expected):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid device token",
        )


def _get_or_create_device(
    db: Session,
    device_id: str,
    metadata: Optional[dict] = None,
) -> models.Device:
    device = db.query(models.Device).filter(models.Device.device_id == device_id).first()
    firmware_version = (metadata or {}).get("firmware_version")
    if device is None:
        device = models.Device(
            device_id=device_id,
            firmware_version=firmware_version,
            metadata_json=metadata or {},
            last_seen_at=_utcnow(),
        )
        db.add(device)
        db.flush()
    else:
        device.last_seen_at = _utcnow()
        if firmware_version:
            device.firmware_version = firmware_version
        if metadata:
            device.metadata_json = {**(device.metadata_json or {}), **metadata}
    return device


def _get_or_create_session(
    db: Session,
    payload: schemas.SessionCreate | schemas.ReadingCreate,
) -> models.MonitoringSession:
    device = _get_or_create_device(db, payload.device_id, getattr(payload, "metadata", {}) or {})
    patient_id = getattr(payload, "patient_id", None) or device.patient_id
    session = (
        db.query(models.MonitoringSession)
        .filter(models.MonitoringSession.session_id == payload.session_id)
        .first()
    )
    if session is None:
        session = models.MonitoringSession(
            session_id=payload.session_id,
            device_id=payload.device_id,
            patient_id=patient_id,
            sampling_rate=payload.sampling_rate,
            status=payload.status,
            metadata_json=getattr(payload, "metadata", {}) or {},
            started_at=getattr(payload, "started_at", None) or _utcnow(),
        )
        db.add(session)
        db.flush()
    else:
        session.status = payload.status or session.status
        session.sampling_rate = payload.sampling_rate or session.sampling_rate
        if session.patient_id is None and patient_id is not None:
            session.patient_id = patient_id
    return session


def _analysis_patient_for_session(session: models.MonitoringSession) -> models.User | None:
    if session.patient is not None:
        return session.patient
    device_patient = session.device.patient if session.device else None
    if device_patient is not None:
        session.patient_id = device_patient.id
        return device_patient
    return None


def _session_or_404(db: Session, session_id: str) -> models.MonitoringSession:
    session = (
        db.query(models.MonitoringSession)
        .filter(models.MonitoringSession.session_id == session_id)
        .first()
    )
    if session is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
    return session


def _device_or_404(db: Session, device_id: str) -> models.Device:
    device = db.query(models.Device).filter(models.Device.device_id == device_id).first()
    if device is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device not found")
    return device


def _readings_for_session(db: Session, session_id: str) -> List[models.RawReading]:
    return (
        db.query(models.RawReading)
        .filter(models.RawReading.session_id == session_id)
        .order_by(models.RawReading.timestamp.asc())
        .all()
    )


def _delete_monitoring_session(db: Session, session_id: str) -> dict:
    session = _session_or_404(db, session_id)
    counts = {
        "clinical_alerts": db.query(models.ClinicalAlert)
        .filter(models.ClinicalAlert.session_id == session_id)
        .delete(synchronize_session=False),
        "analysis_results": db.query(models.AnalysisResult)
        .filter(models.AnalysisResult.session_id == session_id)
        .delete(synchronize_session=False),
        "raw_readings": db.query(models.RawReading)
        .filter(models.RawReading.session_id == session_id)
        .delete(synchronize_session=False),
        "sessions": 1,
    }
    db.delete(session)
    return counts


def _capture_issue(readings: List[models.RawReading]) -> str | None:
    if not readings:
        return None
    latest = readings[-1]
    metadata = latest.metadata_json or {}
    if latest.status == "ppg_sensor_off" or metadata.get("ppg_sensor_ready") is False:
        return "PPG sensor is offline. Check MAX30105 power, ground, SDA, and SCL wiring."
    if latest.status == "no_finger" or metadata.get("finger_detected") is False:
        return "Finger not detected on the PPG sensor. Place your finger over the sensor and keep still."
    return None


def _save_analysis(
    db: Session,
    session_id: str,
    readings: List[models.RawReading],
    patient: models.User | None = None,
) -> models.AnalysisResult:
    try:
        result = get_inference_service().analyze(readings, patient=patient)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    analysis = models.AnalysisResult(
        session_id=session_id,
        model_name=result["model_name"],
        model_version=result["model_version"],
        status=result["status"],
        metrics=result["metrics"],
        signal_quality=result["signal_quality"],
        predictions=result["predictions"],
        alerts=result["alerts"],
        disclaimer=result["disclaimer"],
    )
    db.add(analysis)
    db.flush()
    for alert in result["alerts"]:
        db.add(
            models.ClinicalAlert(
                patient_id=patient.id if patient else None,
                session_id=session_id,
                analysis_id=analysis.id,
                severity=alert.get("severity", "warning"),
                code=alert.get("code", "analysis_alert"),
                message=alert.get("message", "Analysis generated a clinical review alert."),
            )
        )
    return analysis


def _maybe_auto_analyze(db: Session, session_id: str) -> None:
    if not settings.auto_analyze_on_upload:
        return
    readings = _readings_for_session(db, session_id)
    ecg_sample_count = sum(len(reading.ecg or []) for reading in readings)
    required_samples = max(settings.auto_analyze_min_samples, ECG_RECORD_INPUT_SAMPLES)
    if ecg_sample_count < required_samples:
        return
    if _capture_issue(readings):
        return
    if enqueue_analysis(session_id):
        logger.info("Auto-analysis queued for session %s", session_id)


def _build_device_commands(
    reading: models.RawReading,
    analysis: models.AnalysisResult | None = None,
) -> List[dict]:
    commands: List[dict] = []
    metadata = reading.metadata_json or {}
    if reading.status == "ppg_sensor_off" or metadata.get("ppg_sensor_ready") is False:
        commands.append(
            {
                "command_type": "check_sensor_contact",
                "priority": "high",
                "reason": "ppg_sensor_off",
                "message": "PPG sensor is offline. Check MAX30105 power, ground, SDA, and SCL wiring.",
                "payload": {
                    "device_id": reading.device_id,
                    "session_id": reading.session_id,
                    "ppg_reinit_count": metadata.get("ppg_reinit_count"),
                },
            }
        )
    elif reading.status == "no_finger" or metadata.get("finger_detected") is False:
        commands.append(
            {
                "command_type": "check_sensor_contact",
                "priority": "high",
                "reason": "finger_not_detected",
                "message": "Finger not detected on the PPG sensor. Place your finger over the sensor and keep still.",
                "payload": {
                    "device_id": reading.device_id,
                    "session_id": reading.session_id,
                    "ir_mean": metadata.get("ir_mean"),
                    "finger_ir_threshold": metadata.get("finger_ir_threshold"),
                },
            }
        )
    if reading.status == "leads_off":
        commands.append(
            {
                "command_type": "check_sensor_contact",
                "priority": "high",
                "reason": "leads_off",
                "message": "Check electrode and sensor contact before trusting this batch.",
                "payload": {"device_id": reading.device_id, "session_id": reading.session_id},
            }
        )
    if reading.battery is not None and reading.battery < 20:
        commands.append(
            {
                "command_type": "low_battery_warning",
                "priority": "medium",
                "reason": "battery_low",
                "message": "Battery level is low. Recharge or reduce sampling activity.",
                "payload": {"battery": reading.battery},
            }
        )

    if analysis is not None:
        signal_quality = analysis.signal_quality or {}
        ecg_quality = signal_quality.get("ecg", {})
        if ecg_quality.get("score", 1.0) < 0.45:
            commands.append(
                {
                    "command_type": "retry_capture",
                    "priority": "medium",
                    "reason": "low_signal_quality",
                    "message": "Signal quality is low. Reposition the sensor and capture again.",
                    "payload": {"signal_quality": ecg_quality},
                }
            )
        arrhythmia = (analysis.predictions or {}).get("models", {}).get("ecg_arrhythmia_v31", {})
        top_class = arrhythmia.get("top_class") if isinstance(arrhythmia, dict) else None
        if top_class and top_class.get("code") not in {None, "NORM"}:
            commands.append(
                {
                    "command_type": "clinical_review",
                    "priority": "high",
                    "reason": "abnormal_ecg_prediction",
                    "message": "The backend detected a possible abnormal ECG pattern. Escalate for review.",
                    "payload": {"top_class": top_class},
                }
            )

    if not commands:
        commands.append(
            {
                "command_type": "continue",
                "priority": "low",
                "reason": "nominal_capture",
                "message": "Continue sampling.",
                "payload": {"sample_count": reading.sample_count},
            }
        )
    return commands


def _serialize_reading(
    reading: models.RawReading,
    commands: Optional[List[dict]] = None,
) -> dict:
    return {
        "id": reading.id,
        "device_id": reading.device_id,
        "session_id": reading.session_id,
        "timestamp": reading.timestamp,
        "sampling_rate": reading.sampling_rate,
        "ecg": reading.ecg,
        "ppg": reading.ppg,
        "battery": reading.battery,
        "status": reading.status,
        "sample_count": reading.sample_count,
        "metadata_json": reading.metadata_json,
        "received_at": reading.received_at,
        "commands": commands or [],
    }


@router.post(
    "/sessions",
    status_code=status.HTTP_201_CREATED,
    response_model=schemas.SessionOut,
)
def create_session(
    payload: schemas.SessionCreate,
    request: Request,
    response: Response,
    db: Session = Depends(get_db),
):
    _require_device_token(request)
    existing = (
        db.query(models.MonitoringSession)
        .filter(models.MonitoringSession.session_id == payload.session_id)
        .first()
    )
    session = _get_or_create_session(db, payload)
    if existing is not None:
        response.status_code = status.HTTP_200_OK
    db.commit()
    db.refresh(session)
    logger.info("Session %s registered for device %s", session.session_id, session.device_id)
    return session


@router.post(
    "/readings",
    status_code=status.HTTP_201_CREATED,
    response_model=schemas.ReadingOut,
)
def create_reading(
    payload: schemas.ReadingCreate,
    request: Request,
    response: Response,
    db: Session = Depends(get_db),
):
    _require_device_token(request)
    _get_or_create_session(db, payload)
    existing = (
        db.query(models.RawReading)
        .filter(
            models.RawReading.session_id == payload.session_id,
            models.RawReading.timestamp == payload.timestamp,
        )
        .first()
    )
    if existing is not None:
        db.commit()
        response.status_code = status.HTTP_200_OK
        return _serialize_reading(existing, _build_device_commands(existing))

    storage_result = prepare_reading_storage(
        ecg_values=payload.ecg,
        ppg_values=payload.ppg,
        status=payload.status,
        metadata=payload.metadata,
        compact_invalid_signals=settings.compact_invalid_reading_signals,
        max_raw_signal_samples=settings.max_raw_signal_samples_per_reading,
    )
    reading = models.RawReading(
        device_id=payload.device_id,
        session_id=payload.session_id,
        timestamp=payload.timestamp,
        sampling_rate=payload.sampling_rate,
        ecg=storage_result.ecg,
        ppg=storage_result.ppg,
        battery=payload.battery,
        status=storage_result.status,
        sample_count=storage_result.sample_count,
        metadata_json=storage_result.metadata,
    )
    db.add(reading)
    try:
        db.flush()
        db.commit()
    except IntegrityError:
        db.rollback()
        duplicate = (
            db.query(models.RawReading)
            .filter(
                models.RawReading.session_id == payload.session_id,
                models.RawReading.timestamp == payload.timestamp,
            )
            .first()
        )
        if duplicate is None:
            raise
        response.status_code = status.HTTP_200_OK
        return _serialize_reading(duplicate, _build_device_commands(duplicate))

    db.refresh(reading)
    _maybe_auto_analyze(db, payload.session_id)
    analysis = (
        db.query(models.AnalysisResult)
        .filter(models.AnalysisResult.session_id == payload.session_id)
        .order_by(models.AnalysisResult.created_at.desc())
        .first()
    )
    logger.info(
        "Stored %s samples for session %s from device %s",
        reading.sample_count,
        reading.session_id,
        reading.device_id,
    )
    return _serialize_reading(reading, _build_device_commands(reading, analysis))


@router.post(
    "/analyze/{session_id}",
    status_code=status.HTTP_201_CREATED,
    response_model=schemas.AnalysisResultOut,
)
def analyze_session(session_id: str, db: Session = Depends(get_db)):
    session = _session_or_404(db, session_id)
    readings = _readings_for_session(db, session_id)
    if not readings:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No readings found")
    capture_issue = _capture_issue(readings)
    if capture_issue is not None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=capture_issue)
    analysis = _save_analysis(db, session_id, readings, patient=_analysis_patient_for_session(session))
    db.commit()
    db.refresh(analysis)
    logger.info("Analysis %s completed for session %s", analysis.id, session_id)
    return analysis


@router.get("/sessions", response_model=List[schemas.SessionOut])
def list_sessions(
    device_id: Optional[str] = None,
    limit: int = 50,
    db: Session = Depends(get_db),
):
    query = db.query(models.MonitoringSession)
    if device_id:
        query = query.filter(models.MonitoringSession.device_id == device_id)
    return (
        query.order_by(models.MonitoringSession.started_at.desc())
        .limit(max(1, min(limit, 200)))
        .all()
    )


@router.get("/sessions/{session_id}", response_model=schemas.SessionOut)
def get_session(session_id: str, db: Session = Depends(get_db)):
    return _session_or_404(db, session_id)


@router.get("/sessions/{session_id}/readings", response_model=List[schemas.ReadingOut])
def get_session_readings(
    session_id: str,
    limit: int = 500,
    db: Session = Depends(get_db),
):
    _session_or_404(db, session_id)
    latest_readings = (
        db.query(models.RawReading)
        .filter(models.RawReading.session_id == session_id)
        .order_by(models.RawReading.timestamp.desc())
        .limit(max(1, min(limit, 2000)))
        .all()
    )
    return list(reversed(latest_readings))


@router.get("/sessions/{session_id}/analysis", response_model=List[schemas.AnalysisResultOut])
def get_session_analysis(session_id: str, db: Session = Depends(get_db)):
    _session_or_404(db, session_id)
    return (
        db.query(models.AnalysisResult)
        .filter(models.AnalysisResult.session_id == session_id)
        .order_by(models.AnalysisResult.created_at.desc())
        .all()
    )


@router.delete("/sessions/{session_id}", status_code=status.HTTP_200_OK)
def delete_session(session_id: str, db: Session = Depends(get_db)):
    counts = _delete_monitoring_session(db, session_id)
    db.commit()
    logger.info("Deleted monitoring session %s with counts %s", session_id, counts)
    return {"deleted": counts}


@router.delete("/sessions", status_code=status.HTTP_200_OK)
def delete_all_sessions(db: Session = Depends(get_db)):
    counts = {
        "clinical_alerts": db.query(models.ClinicalAlert).delete(synchronize_session=False),
        "analysis_results": db.query(models.AnalysisResult).delete(synchronize_session=False),
        "raw_readings": db.query(models.RawReading).delete(synchronize_session=False),
        "sessions": db.query(models.MonitoringSession).delete(synchronize_session=False),
    }
    db.commit()
    logger.warning("Deleted all monitoring sessions and records with counts %s", counts)
    return {"deleted": counts}


@router.get("/analysis-worker/status")
def get_analysis_worker_status():
    state = analysis_worker_state()
    return {
        "running": state.running,
        "queued": state.queued,
        "processed": state.processed,
        "failed": state.failed,
    }


@router.get("/ecg/classifications")
def get_ecg_classifications():
    return [
        {
            "code": "NORM",
            "label": "Normal ECG",
            "description": "No clear abnormalities detected in the analyzed ECG window.",
            "color_hex": "#00C853",
            "icon_name": "check_circle_outline",
        },
        {
            "code": "MI",
            "label": "Myocardial Infarction Pattern",
            "description": "Model may flag ischemic or infarction-like morphology.",
            "color_hex": "#E53935",
            "icon_name": "warning_amber_rounded",
        },
        {
            "code": "STTC",
            "label": "ST/T Wave Change",
            "description": "Model may flag ST segment or T wave changes.",
            "color_hex": "#FF6F00",
            "icon_name": "show_chart",
        },
        {
            "code": "CD",
            "label": "Conduction Disturbance",
            "description": "Model may flag abnormal electrical conduction timing.",
            "color_hex": "#7B1FA2",
            "icon_name": "electric_bolt_outlined",
        },
        {
            "code": "HYP",
            "label": "Hypertrophy Pattern",
            "description": "Model may flag morphology associated with hypertrophy.",
            "color_hex": "#0288D1",
            "icon_name": "favorite_border",
        },
    ]


@router.get("/ecg/classification-levels")
def get_classification_levels():
    return [
        {
            "level_type": "beat",
            "title": "Beat-Level Classification",
            "subtitle": "Single-heartbeat rhythm categories.",
            "codes": [
                {"code": "N", "color_hex": "#00C853"},
                {"code": "S", "color_hex": "#0288D1"},
                {"code": "V", "color_hex": "#E53935"},
                {"code": "F", "color_hex": "#FF6F00"},
                {"code": "Q", "color_hex": "#607D8B"},
            ],
        },
        {
            "level_type": "record",
            "title": "Record-Level Classification",
            "subtitle": "Full ECG window decision-support classes.",
            "codes": [
                {"code": "NORM", "color_hex": "#00C853"},
                {"code": "MI", "color_hex": "#E53935"},
                {"code": "STTC", "color_hex": "#FF6F00"},
                {"code": "CD", "color_hex": "#7B1FA2"},
                {"code": "HYP", "color_hex": "#0288D1"},
            ],
        },
    ]


@router.get("/devices", response_model=List[schemas.DeviceOut])
def list_devices(patient_id: Optional[int] = None, db: Session = Depends(get_db)):
    query = db.query(models.Device)
    if patient_id is not None:
        query = query.filter(models.Device.patient_id == patient_id)
    return query.order_by(models.Device.last_seen_at.desc().nullslast()).all()


@router.post(
    "/devices/register",
    status_code=status.HTTP_201_CREATED,
    response_model=schemas.DeviceOut,
)
def register_device(
    payload: schemas.DeviceRegister,
    request: Request,
    response: Response,
    db: Session = Depends(get_db),
):
    _require_device_token(request)
    existing = db.query(models.Device).filter(models.Device.device_id == payload.device_id).first()
    device = _get_or_create_device(db, payload.device_id, payload.metadata)
    if existing is not None:
        response.status_code = status.HTTP_200_OK
    device.label = payload.label or device.label
    device.firmware_version = payload.firmware_version or device.firmware_version
    if payload.patient_id is not None:
        patient = db.query(models.User).filter(
            models.User.id == payload.patient_id,
            models.User.role == "patient",
        ).first()
        if patient is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Patient not found")
        device.patient_id = payload.patient_id
    db.commit()
    db.refresh(device)
    return device


@router.patch("/devices/{device_id}/assign", response_model=schemas.DeviceOut)
def assign_device(
    device_id: str,
    payload: schemas.DeviceAssign,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    device = _device_or_404(db, device_id)
    if payload.patient_id is None:
        if current_user.role not in {"admin", "doctor"} and current_user.id != device.patient_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="not authorized")
        device.patient_id = None
    else:
        patient = db.query(models.User).filter(
            models.User.id == payload.patient_id,
            models.User.role == "patient",
        ).first()
        if patient is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Patient not found")
        if current_user.role == "patient" and current_user.id != payload.patient_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="not authorized")
        if current_user.role == "doctor" and patient.doc_id not in {None, current_user.id}:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Patient is assigned to another doctor")
        device.patient_id = payload.patient_id
    db.commit()
    db.refresh(device)
    return device


@router.get("/devices/{device_id}", response_model=schemas.DeviceOut)
def get_device(device_id: str, db: Session = Depends(get_db)):
    return _device_or_404(db, device_id)


@router.get("/alerts", response_model=List[schemas.ClinicalAlertOut])
def list_alerts(
    patient_id: Optional[int] = None,
    status_filter: str = "open",
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    query = db.query(models.ClinicalAlert)
    if status_filter:
        query = query.filter(models.ClinicalAlert.status == status_filter)
    if patient_id is not None:
        query = query.filter(models.ClinicalAlert.patient_id == patient_id)
    if current_user.role == "patient":
        query = query.filter(models.ClinicalAlert.patient_id == current_user.id)
    elif current_user.role == "doctor":
        patient_ids = [
            patient.id
            for patient in db.query(models.User.id)
            .filter(models.User.role == "patient", models.User.doc_id == current_user.id)
            .all()
        ]
        query = query.filter(models.ClinicalAlert.patient_id.in_(patient_ids))
    return (
        query.order_by(models.ClinicalAlert.created_at.desc())
        .limit(max(1, min(limit, 200)))
        .all()
    )


@router.patch("/alerts/{alert_id}/resolve", response_model=schemas.ClinicalAlertOut)
def resolve_alert(
    alert_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    if current_user.role not in {"admin", "doctor"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Doctor or admin access required")
    alert = db.query(models.ClinicalAlert).filter(models.ClinicalAlert.id == alert_id).first()
    if alert is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Alert not found")
    if current_user.role == "doctor" and alert.patient_id is not None:
        patient = db.query(models.User).filter(models.User.id == alert.patient_id).first()
        if patient is None or patient.doc_id != current_user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="not authorized")
    alert.status = "resolved"
    alert.resolved_at = _utcnow()
    db.commit()
    db.refresh(alert)
    return alert


@router.get("/ai/models")
def get_ai_models():
    return get_inference_service().metadata()


@router.get("/ecg/current-condition")
def get_current_condition(db: Session = Depends(get_db)):
    latest = db.query(models.AnalysisResult).order_by(models.AnalysisResult.created_at.desc()).first()
    if latest is None:
        return {
            "code": "UNKNOWN",
            "label": "No Analysis Yet",
            "description": "Upload a session and run analysis to see the latest ECG condition.",
            "color_hex": "#607D8B",
            "icon_name": "help_outline",
        }
    summary = (latest.predictions or {}).get("summary", {})
    level = summary.get("arrhythmia_risk", "unknown")
    color = "#00C853" if level == "low" else "#FF6F00" if level == "moderate" else "#E53935"
    return {
        "code": level.upper(),
        "label": f"Arrhythmia Risk: {level.title()}",
        "description": latest.disclaimer,
        "color_hex": color,
        "icon_name": "monitor_heart",
    }
