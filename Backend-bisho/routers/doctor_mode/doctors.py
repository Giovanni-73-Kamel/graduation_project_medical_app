from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

import app.database as database
import app.models as models
import app.schemas as schemas
from routers import oauth2

router = APIRouter(prefix="/doctors", tags=["Doctors"])


def _doctor_out(doctor: models.User) -> dict:
    return {
        "id": doctor.id,
        "name": doctor.username,
        "email": doctor.email,
        "phone_number": doctor.phone_number,
    }


def _doctor_or_404(db: Session, doctor_id: int) -> models.User:
    doctor = (
        db.query(models.User)
        .filter(models.User.id == doctor_id, models.User.role == "doctor")
        .first()
    )
    if doctor is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Doctor not found")
    return doctor


@router.get("", response_model=List[schemas.DoctorOut])
@router.get("/", response_model=List[schemas.DoctorOut])
def list_doctors(
    search: str = "",
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    query = db.query(models.User).filter(models.User.role == "doctor")
    search_term = search.strip()
    if search_term:
        like_term = f"%{search_term}%"
        query = query.filter(
            or_(
                models.User.username.ilike(like_term),
                models.User.email.ilike(like_term),
            )
        )
    doctors = query.order_by(models.User.username.asc()).all()
    return [_doctor_out(doctor) for doctor in doctors]


@router.get("/{doctor_id}", response_model=schemas.DoctorOut)
def get_doctor(
    doctor_id: int,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    return _doctor_out(_doctor_or_404(db, doctor_id))


@router.post("/", status_code=status.HTTP_201_CREATED, response_model=schemas.DoctorOut)
def create_doctor(
    doctor: schemas.DoctorCreate,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    existing = db.query(models.User).filter(models.User.email == doctor.email.lower().strip()).first()
    if existing is not None:
        if existing.role != "doctor":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email belongs to a non-doctor user")
        return _doctor_out(existing)

    new_doctor = models.User(
        username=doctor.name.strip(),
        email=doctor.email.lower().strip(),
        phone_number=doctor.phone_number.strip(),
        role="doctor",
        is_registered=False,
    )
    db.add(new_doctor)
    db.commit()
    db.refresh(new_doctor)
    return _doctor_out(new_doctor)
