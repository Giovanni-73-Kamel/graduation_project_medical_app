from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

import app.database as database
import app.models as models
import app.schemas as schemas
from routers import oauth2

router = APIRouter(prefix="/patients", tags=["Patients"])


def _require_doctor(current_user: models.User) -> None:
    if current_user.role != "doctor":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Doctor access required")


@router.post("/createpatients", status_code=status.HTTP_201_CREATED, response_model=schemas.PatientOut)
def create_patient(
    patient: schemas.Patient,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    _require_doctor(current_user)
    new_patient = models.User(doc_id=current_user.id, role="patient", is_registered=False, **patient.dict())
    db.add(new_patient)
    db.commit()
    db.refresh(new_patient)
    return new_patient


@router.get("/")
def get_patients(
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    _require_doctor(current_user)
    patients = db.query(models.User).filter(models.User.doc_id == current_user.id).all()
    return patients


@router.get("/{id}", response_model=schemas.PatientOut)
def get_patient(
    id: int,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    patient = db.query(models.User).filter(models.User.id == id).first()
    if not patient:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found")
    if current_user.role == "doctor" and patient.doc_id == current_user.id:
        return patient
    if current_user.id == patient.id:
        return patient
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="not authorized to access this patient")


@router.put("/{id}", response_model=schemas.PatientOut)
def update_patient(
    id: int,
    updated_patient: schemas.Patient,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    _require_doctor(current_user)
    patient_query = db.query(models.User).filter(models.User.id == id, models.User.doc_id == current_user.id)
    patient = patient_query.first()
    if patient is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found")
    patient.username = updated_patient.username
    patient.phone_number = updated_patient.phone_number
    patient.email = updated_patient.email
    db.commit()
    db.refresh(patient)
    return patient


@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_patient(
    id: int,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    _require_doctor(current_user)
    patient_query = db.query(models.User).filter(models.User.id == id, models.User.doc_id == current_user.id)
    patient = patient_query.first()
    if not patient:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found")
    patient_query.delete(synchronize_session=False)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
