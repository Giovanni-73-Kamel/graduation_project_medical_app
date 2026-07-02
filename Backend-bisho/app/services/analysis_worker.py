from __future__ import annotations

import logging
import queue
import threading
from dataclasses import dataclass
from typing import Any

import app.models as models
from app.database import SessionLocal
from app.services.ai_inference import get_inference_service

logger = logging.getLogger(__name__)


@dataclass
class AnalysisWorkerState:
    running: bool = False
    queued: int = 0
    processed: int = 0
    failed: int = 0


_queue: queue.Queue[str | None] = queue.Queue()
_queued_session_ids: set[str] = set()
_lock = threading.Lock()
_thread: threading.Thread | None = None
_processed = 0
_failed = 0


def _capture_issue(readings: list[models.RawReading]) -> str | None:
    if not readings:
        return None
    latest = readings[-1]
    metadata = latest.metadata_json or {}
    if latest.status == "ppg_sensor_off" or metadata.get("ppg_sensor_ready") is False:
        return "PPG sensor is offline."
    if latest.status == "no_finger" or metadata.get("finger_detected") is False:
        return "Finger not detected."
    return None


def _readings_for_session(db: Any, session_id: str) -> list[models.RawReading]:
    return (
        db.query(models.RawReading)
        .filter(models.RawReading.session_id == session_id)
        .order_by(models.RawReading.timestamp.asc())
        .all()
    )


def _analysis_patient_for_session(session: models.MonitoringSession) -> models.User | None:
    if session.patient is not None:
        return session.patient
    device_patient = session.device.patient if session.device else None
    if device_patient is not None:
        session.patient_id = device_patient.id
        return device_patient
    return None


def _save_analysis(db: Any, session: models.MonitoringSession, readings: list[models.RawReading]) -> models.AnalysisResult:
    patient = _analysis_patient_for_session(session)
    result = get_inference_service().analyze(readings, patient=patient)
    analysis = models.AnalysisResult(
        session_id=session.session_id,
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
                session_id=session.session_id,
                analysis_id=analysis.id,
                severity=alert.get("severity", "warning"),
                code=alert.get("code", "analysis_alert"),
                message=alert.get("message", "Analysis generated a clinical review alert."),
            )
        )
    return analysis


def analyze_session_job(session_id: str) -> None:
    db = SessionLocal()
    try:
        session = (
            db.query(models.MonitoringSession)
            .filter(models.MonitoringSession.session_id == session_id)
            .first()
        )
        if session is None:
            logger.warning("Analysis worker skipped missing session %s", session_id)
            return
        readings = _readings_for_session(db, session_id)
        if not readings:
            logger.info("Analysis worker skipped session %s without readings", session_id)
            return
        issue = _capture_issue(readings)
        if issue:
            logger.info("Analysis worker skipped session %s: %s", session_id, issue)
            return
        analysis = _save_analysis(db, session, readings)
        db.commit()
        logger.info("Analysis worker saved analysis %s for session %s", analysis.id, session_id)
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def start_analysis_worker() -> None:
    global _thread
    with _lock:
        if _thread is not None and _thread.is_alive():
            return
        _thread = threading.Thread(target=_worker_loop, name="analysis-worker", daemon=True)
        _thread.start()
        logger.info("Analysis worker started")


def stop_analysis_worker(timeout: float = 5.0) -> None:
    global _thread
    with _lock:
        thread = _thread
        if thread is None:
            return
        _queue.put(None)
    thread.join(timeout=timeout)
    with _lock:
        _thread = None
    logger.info("Analysis worker stopped")


def enqueue_analysis(session_id: str) -> bool:
    with _lock:
        if session_id in _queued_session_ids:
            return False
        _queued_session_ids.add(session_id)
        _queue.put(session_id)
    logger.info("Queued analysis for session %s", session_id)
    return True


def analysis_worker_state() -> AnalysisWorkerState:
    with _lock:
        return AnalysisWorkerState(
            running=_thread is not None and _thread.is_alive(),
            queued=_queue.qsize(),
            processed=_processed,
            failed=_failed,
        )


def _worker_loop() -> None:
    global _processed, _failed
    while True:
        session_id = _queue.get()
        if session_id is None:
            _queue.task_done()
            return
        try:
            analyze_session_job(session_id)
            with _lock:
                _processed += 1
        except Exception:
            logger.exception("Analysis worker failed for session %s", session_id)
            with _lock:
                _failed += 1
        finally:
            with _lock:
                _queued_session_ids.discard(session_id)
            _queue.task_done()
