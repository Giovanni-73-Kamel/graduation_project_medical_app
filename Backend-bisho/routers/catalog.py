from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends
from sqlalchemy import or_
from sqlalchemy.orm import Session

import app.database as database
import app.models as models
import app.schemas as schemas
from routers import oauth2

clinics_router = APIRouter(prefix="/clinics", tags=["Clinics"])
medications_router = APIRouter(prefix="/medications", tags=["Medications"])

DEFAULT_CLINICS = [
    {
        "id": 1,
        "name": "Cardiology Clinic",
        "address": "Main medical center",
        "phone": "",
        "specialty": "Cardiology",
        "metadata_json": {},
    },
    {
        "id": 2,
        "name": "Remote Monitoring Unit",
        "address": "Telehealth",
        "phone": "",
        "specialty": "Digital health",
        "metadata_json": {},
    },
]

DEFAULT_MEDICATIONS = [
    {
        "id": 1,
        "name": "Aspirin",
        "category": "Antiplatelet",
        "dosage_form": "Tablet",
        "description": "Common cardiovascular medication. Use only as prescribed.",
    },
    {
        "id": 2,
        "name": "Atorvastatin",
        "category": "Statin",
        "dosage_form": "Tablet",
        "description": "Cholesterol-lowering medication. Use only as prescribed.",
    },
    {
        "id": 3,
        "name": "Metoprolol",
        "category": "Beta blocker",
        "dosage_form": "Tablet",
        "description": "Heart-rate and blood-pressure medication. Use only as prescribed.",
    },
]


@clinics_router.get("/", response_model=List[schemas.ClinicOut])
def get_clinics(
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    clinics = db.query(models.Clinic).order_by(models.Clinic.name.asc()).all()
    return clinics or DEFAULT_CLINICS


@medications_router.get("/", response_model=List[schemas.MedicationOut])
def get_medications(
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    medications = db.query(models.Medication).order_by(models.Medication.name.asc()).all()
    return medications or DEFAULT_MEDICATIONS


@medications_router.get("/search", response_model=List[schemas.MedicationOut])
def search_medications(
    q: str = "",
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    query = q.strip()
    if not query:
        return get_medications(db=db, current_user=current_user)
    medications = (
        db.query(models.Medication)
        .filter(
            or_(
                models.Medication.name.ilike(f"%{query}%"),
                models.Medication.category.ilike(f"%{query}%"),
            )
        )
        .order_by(models.Medication.name.asc())
        .all()
    )
    if medications:
        return medications
    return [
        medication
        for medication in DEFAULT_MEDICATIONS
        if query.lower() in medication["name"].lower()
        or query.lower() in (medication["category"] or "").lower()
    ]
