from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

import app.database as database
import app.models as models
import app.schemas as schemas
from routers import oauth2

router = APIRouter(prefix="/medical-records", tags=["Medical Records"])


def _can_access_patient(current_user: models.User, patient_id: int) -> bool:
    if current_user.role == "admin":
        return True
    if current_user.role == "patient":
        return current_user.id == patient_id
    if current_user.role == "doctor":
        return True
    return False


@router.get("/patient/{patient_id}", response_model=List[schemas.MedicalRecordOut])
def get_patient_records(
    patient_id: int,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    if not _can_access_patient(current_user, patient_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="not authorized")
    return (
        db.query(models.MedicalRecord)
        .filter(models.MedicalRecord.patient_id == patient_id)
        .order_by(models.MedicalRecord.created_at.desc())
        .all()
    )


@router.post("/", status_code=status.HTTP_201_CREATED, response_model=schemas.MedicalRecordOut)
def create_record(
    payload: schemas.MedicalRecordCreate,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    if not _can_access_patient(current_user, payload.patient_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="not authorized")
    doctor_id = payload.doctor_id
    if current_user.role == "doctor":
        doctor_id = current_user.id
    record = models.MedicalRecord(
        patient_id=payload.patient_id,
        doctor_id=doctor_id,
        title=payload.title,
        diagnosis=payload.diagnosis,
        notes=payload.notes,
        metadata_json=payload.metadata or {},
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


@router.put("/{record_id}", response_model=schemas.MedicalRecordOut)
def update_record(
    record_id: int,
    payload: schemas.MedicalRecordUpdate,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    record = db.query(models.MedicalRecord).filter(models.MedicalRecord.id == record_id).first()
    if record is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medical record not found")
    if not _can_access_patient(current_user, record.patient_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="not authorized")
    update_data = payload.model_dump(exclude_unset=True)
    if "metadata" in update_data:
        record.metadata_json = update_data.pop("metadata") or {}
    for field, value in update_data.items():
        setattr(record, field, value)
    db.commit()
    db.refresh(record)
    return record
