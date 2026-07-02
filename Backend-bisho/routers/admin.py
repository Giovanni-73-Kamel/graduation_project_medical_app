from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

import app.database as database
import app.models as models
from routers import oauth2

router = APIRouter(prefix="/admin", tags=["Admin"])


def _require_admin_or_doctor(current_user: models.User) -> None:
    if current_user.role not in {"admin", "doctor"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin or doctor access required")


def _require_admin(current_user: models.User) -> None:
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")


@router.get("/dashboard")
def get_dashboard(
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    _require_admin_or_doctor(current_user)
    user_query = db.query(models.User)
    if current_user.role == "doctor":
        user_query = user_query.filter(
            (models.User.id == current_user.id) | (models.User.doc_id == current_user.id)
        )
    total_users = user_query.count()
    total_patients = user_query.filter(models.User.role == "patient").count()
    total_doctors = db.query(models.User).filter(models.User.role == "doctor").count()
    total_devices = db.query(models.Device).count()
    active_sessions = db.query(models.MonitoringSession).filter(models.MonitoringSession.status == "active").count()
    open_alerts = db.query(models.ClinicalAlert).filter(models.ClinicalAlert.status == "open").count()
    latest_analysis = db.query(func.max(models.AnalysisResult.created_at)).scalar()
    return {
        "total_users": total_users,
        "total_patients": total_patients,
        "total_doctors": total_doctors,
        "total_devices": total_devices,
        "active_sessions": active_sessions,
        "open_alerts": open_alerts,
        "latest_analysis_at": latest_analysis,
    }


@router.get("/users")
def get_users(
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    _require_admin(current_user)
    users = db.query(models.User).order_by(models.User.id.asc()).all()
    return [
        {
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "role": user.role,
            "phone_number": user.phone_number,
            "date_of_birth": user.date_of_birth,
            "age": user.age,
            "height": user.height,
            "weight": user.weight,
            "doctor_id": user.doc_id,
        }
        for user in users
    ]
