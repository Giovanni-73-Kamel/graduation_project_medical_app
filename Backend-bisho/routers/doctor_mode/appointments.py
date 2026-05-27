from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

import app.database as database
import app.models as models
import app.schemas as schemas
from routers import oauth2

router = APIRouter(prefix="/appointments", tags=["Appointments"])


def _require_doctor(current_user: models.User) -> None:
    if current_user.role != "doctor":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Doctor access required")


def _patient_belongs_to_doctor(db: Session, patient_id: int, doctor_id: int) -> models.User:
    patient = db.query(models.User).filter(models.User.id == patient_id).first()
    if patient is None or patient.role != "patient" or patient.doc_id != doctor_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Patient is not assigned to this doctor")
    return patient


@router.post("/createappointment/", status_code=status.HTTP_201_CREATED, response_model=schemas.AppointmentOut)
def create_appointment(
    appointment: schemas.Appointment,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    _require_doctor(current_user)
    _patient_belongs_to_doctor(db, appointment.patient_id, current_user.id)

    new_appointment = models.Appointment(doctor_id=current_user.id, **appointment.dict())
    db.add(new_appointment)
    db.flush()

    new_reminder = models.Reminder(
        owner_id=appointment.patient_id,
        title=appointment.title,
        type="Appointment",
        date=appointment.date,
        time_hour=appointment.time_hour,
        time_minute=appointment.time_minute,
        frequency="Once",
        notes=f"Appointment with doctor id {current_user.id}",
    )
    db.add(new_reminder)
    db.commit()
    db.refresh(new_appointment)
    return new_appointment


@router.get("/")
def get_appointments(
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    _require_doctor(current_user)
    appointments = (
        db.query(models.Appointment, models.User)
        .join(models.User, models.Appointment.patient_id == models.User.id)
        .filter(models.Appointment.doctor_id == current_user.id)
        .all()
    )

    result = []
    for appointment, patient in appointments:
        time_str = f"{appointment.time_hour:02d}:{appointment.time_minute:02d}"
        result.append(
            {
                "id": appointment.id,
                "patient_id": appointment.patient_id,
                "patient_name": patient.username,
                "date": appointment.date,
                "time_hour": appointment.time_hour,
                "time_minute": appointment.time_minute,
                "time": time_str,
                "title": appointment.title,
            }
        )

    result.sort(key=lambda x: (x["date"], x["time_hour"], x["time_minute"]))
    return result


@router.get("/{id}", response_model=schemas.AppointmentOut)
def get_appointment(
    id: int,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    appointment = db.query(models.Appointment).filter(models.Appointment.id == id).first()
    if not appointment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Appointment not found")
    if current_user.id != appointment.doctor_id and current_user.id != appointment.patient_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="not authorized to access this appointment")
    return appointment


@router.put("/{id}", response_model=schemas.AppointmentOut)
def update_appointment(
    id: int,
    updated_appointment: schemas.Appointment,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    _require_doctor(current_user)
    appointment_query = db.query(models.Appointment).filter(
        models.Appointment.id == id,
        models.Appointment.doctor_id == current_user.id,
    )
    appointment = appointment_query.first()
    if appointment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Appointment not found")
    _patient_belongs_to_doctor(db, updated_appointment.patient_id, current_user.id)
    appointment.patient_id = updated_appointment.patient_id
    appointment.date = updated_appointment.date
    appointment.time_hour = updated_appointment.time_hour
    appointment.time_minute = updated_appointment.time_minute
    appointment.title = updated_appointment.title
    db.commit()
    db.refresh(appointment)
    return appointment


@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_appointment(
    id: int,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    _require_doctor(current_user)
    appointment_query = db.query(models.Appointment).filter(
        models.Appointment.id == id,
        models.Appointment.doctor_id == current_user.id,
    )
    appointment = appointment_query.first()
    if not appointment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Appointment not found")
    appointment_query.delete(synchronize_session=False)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
