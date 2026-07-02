from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

import app.database as database
import app.models as models
import app.schemas as schemas
from routers import oauth2

router = APIRouter(prefix="/prescriptions", tags=["Prescriptions"])


def _appointment_or_404(db: Session, appointment_id: int) -> models.Appointment:
    appointment = db.query(models.Appointment).filter(models.Appointment.id == appointment_id).first()
    if appointment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Appointment not found")
    return appointment


def _can_access(current_user: models.User, patient_id: int, doctor_id: int | None = None) -> bool:
    if current_user.role == "admin":
        return True
    if current_user.role == "patient":
        return current_user.id == patient_id
    if current_user.role == "doctor":
        return doctor_id is None or current_user.id == doctor_id
    return False


@router.get("/appointment/{appointment_id}", response_model=List[schemas.PrescriptionOut])
def get_prescriptions_by_appointment(
    appointment_id: int,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    appointment = _appointment_or_404(db, appointment_id)
    if not _can_access(current_user, appointment.patient_id, appointment.doctor_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="not authorized")
    return (
        db.query(models.Prescription)
        .filter(models.Prescription.appointment_id == appointment_id)
        .order_by(models.Prescription.created_at.desc())
        .all()
    )


@router.post("/", status_code=status.HTTP_201_CREATED, response_model=schemas.PrescriptionOut)
def create_prescription(
    payload: schemas.PrescriptionCreate,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    appointment = None
    patient_id = payload.patient_id
    doctor_id = payload.doctor_id
    if payload.appointment_id is not None:
        appointment = _appointment_or_404(db, payload.appointment_id)
        patient_id = appointment.patient_id
        doctor_id = appointment.doctor_id
    if patient_id is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="patient_id is required")
    if current_user.role == "doctor":
        doctor_id = current_user.id
    if not _can_access(current_user, patient_id, doctor_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="not authorized")
    prescription = models.Prescription(
        appointment_id=appointment.id if appointment else payload.appointment_id,
        patient_id=patient_id,
        doctor_id=doctor_id,
        medication_name=payload.medication_name,
        dosage=payload.dosage,
        frequency=payload.frequency,
        instructions=payload.instructions,
    )
    db.add(prescription)
    db.commit()
    db.refresh(prescription)
    return prescription


@router.put("/{prescription_id}", response_model=schemas.PrescriptionOut)
def update_prescription(
    prescription_id: int,
    payload: schemas.PrescriptionUpdate,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    prescription = db.query(models.Prescription).filter(models.Prescription.id == prescription_id).first()
    if prescription is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Prescription not found")
    if not _can_access(current_user, prescription.patient_id, prescription.doctor_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="not authorized")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(prescription, field, value)
    db.commit()
    db.refresh(prescription)
    return prescription
