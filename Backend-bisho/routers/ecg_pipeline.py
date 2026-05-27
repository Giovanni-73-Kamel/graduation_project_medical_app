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
from app.services.ai_inference import get_inference_service

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


def _get_or_create_device(db: Session, device_id: str) -> models.Device:
    device = db.query(models.Device).filter(models.Device.device_id == device_id).first()
    if device is None:
        device = models.Device(device_id=device_id, last_seen_at=_utcnow())
        db.add(device)
        db.flush()
    else:
        device.last_seen_at = _utcnow()
    return device


def _get_or_create_session(
    db: Session,
    payload: schemas.SessionCreate | schemas.ReadingCreate,
) -> models.MonitoringSession:
    _get_or_create_device(db, payload.device_id)
    session = (
        db.query(models.MonitoringSession)
        .filter(models.MonitoringSession.session_id == payload.session_id)
        .first()
    )
    if session is None:
        session = models.MonitoringSession(
            session_id=payload.session_id,
            device_id=payload.device_id,
            patient_id=getattr(payload, "patient_id", None),
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
    return session


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
    return analysis


def _maybe_auto_analyze(db: Session, session_id: str) -> None:
    if not settings.auto_analyze_on_upload:
        return
    readings = _readings_for_session(db, session_id)
    sample_count = sum(reading.sample_count for reading in readings)
    if sample_count < settings.auto_analyze_min_samples:
        return
    try:
        session = _session_or_404(db, session_id)
        _save_analysis(db, session_id, readings, patient=session.patient)
    except Exception:
        logger.exception("Auto-analysis failed for session %s", session_id)


def _build_device_commands(
    reading: models.RawReading,
    analysis: models.AnalysisResult | None = None,
) -> List[dict]:
    commands: List[dict] = []
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

    reading = models.RawReading(
        device_id=payload.device_id,
        session_id=payload.session_id,
        timestamp=payload.timestamp,
        sampling_rate=payload.sampling_rate,
        ecg=payload.ecg,
        ppg=payload.ppg,
        battery=payload.battery,
        status=payload.status,
        sample_count=min(len(payload.ecg), len(payload.ppg)),
        metadata_json=payload.metadata,
    )
    db.add(reading)
    try:
        db.flush()
        _maybe_auto_analyze(db, payload.session_id)
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
    analysis = _save_analysis(db, session_id, readings, patient=session.patient)
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
    return (
        db.query(models.RawReading)
        .filter(models.RawReading.session_id == session_id)
        .order_by(models.RawReading.timestamp.asc())
        .limit(max(1, min(limit, 2000)))
        .all()
    )


@router.get("/sessions/{session_id}/analysis", response_model=List[schemas.AnalysisResultOut])
def get_session_analysis(session_id: str, db: Session = Depends(get_db)):
    _session_or_404(db, session_id)
    return (
        db.query(models.AnalysisResult)
        .filter(models.AnalysisResult.session_id == session_id)
        .order_by(models.AnalysisResult.created_at.desc())
        .all()
    )


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
def list_devices(db: Session = Depends(get_db)):
    return db.query(models.Device).order_by(models.Device.last_seen_at.desc().nullslast()).all()


@router.get("/devices/{device_id}", response_model=schemas.DeviceOut)
def get_device(device_id: str, db: Session = Depends(get_db)):
    return _device_or_404(db, device_id)


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
