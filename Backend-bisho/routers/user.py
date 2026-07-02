from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

import app.models as models
import app.schemas as schemas
import app.utils as utils
from app.database import get_db
from routers import oauth2

router = APIRouter()


def _normalize_email(value: str | None) -> str | None:
    if value is None:
        return None
    return value.lower().strip()


def _ensure_unique_email(db: Session, email: str, current_user_id: int | None = None) -> None:
    query = db.query(models.User).filter(models.User.email == email)
    if current_user_id is not None:
        query = query.filter(models.User.id != current_user_id)
    if query.first() is not None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="User with this email already exists")


@router.post("/users/", status_code=status.HTTP_201_CREATED, response_model=schemas.UserOut)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    normalized_email = _normalize_email(user.email)
    if normalized_email is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email is required")

    existing_user = (
        db.query(models.User)
        .filter(models.User.email == normalized_email, models.User.is_registered.is_(True))
        .first()
    )
    if existing_user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="User with this email already exists")

    hashed_password = utils.hash(user.password)
    role = user.role.lower().strip()

    if role == "patient":
        doc_email = _normalize_email(user.doctor_email)
        emerg_email = _normalize_email(user.emergency_email)
        if not doc_email or not emerg_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Doctor and emergency contact details are required for patient signup",
            )

        doc = db.query(models.User).filter(models.User.email == doc_email).first()
        if doc and doc.role != "doctor":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Provided doctor email is not a doctor")
        if not doc:
            doc = models.User(
                username=user.doctor_name,
                email=doc_email,
                phone_number=user.doctor_phone,
                role="doctor",
                is_registered=False,
            )
            db.add(doc)
            db.flush()

        emerg = db.query(models.Emergency).filter(models.Emergency.email == emerg_email).first()
        if not emerg:
            emerg = models.Emergency(
                name=user.emergency_name,
                email=emerg_email,
                phone_number=user.emergency_phone,
            )
            db.add(emerg)
            db.flush()

        new_user = models.User(
            username=user.username,
            email=normalized_email,
            password=hashed_password,
            role="patient",
            phone_number=user.phone_number,
            date_of_birth=user.date_of_birth,
            age=user.age,
            height=user.height,
            weight=user.weight,
            doc_id=doc.id,
            emergency_id=emerg.id,
            is_registered=True,
        )
        db.add(new_user)
        db.flush()

        db.add_all(
            [
                models.Contact(
                    owner_id=new_user.id,
                    name=user.doctor_name,
                    email=doc_email,
                    phone=user.doctor_phone,
                    type="doctor",
                ),
                models.Contact(
                    owner_id=new_user.id,
                    name=user.emergency_name,
                    email=emerg_email,
                    phone=user.emergency_phone,
                    type="emergency",
                ),
            ]
        )

    elif role == "doctor":
        stored_doc = db.query(models.User).filter(models.User.email == normalized_email).first()
        if stored_doc:
            if stored_doc.role != "doctor":
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Provided email is not a doctor account")
            stored_doc.username = user.username
            stored_doc.email = normalized_email
            stored_doc.password = hashed_password
            stored_doc.phone_number = user.phone_number
            stored_doc.date_of_birth = user.date_of_birth
            stored_doc.age = user.age
            stored_doc.height = user.height
            stored_doc.weight = user.weight
            stored_doc.is_registered = True
            new_user = stored_doc
        else:
            new_user = models.User(
                username=user.username,
                email=normalized_email,
                password=hashed_password,
                role="doctor",
                phone_number=user.phone_number,
                date_of_birth=user.date_of_birth,
                age=user.age,
                height=user.height,
                weight=user.weight,
                is_registered=True,
            )
            db.add(new_user)
    else:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid role")

    db.commit()
    db.refresh(new_user)
    return new_user


@router.get("/users/me", response_model=schemas.UserOut)
def get_me(current_user=Depends(oauth2.get_current_user)):
    return current_user


@router.put("/users/me", response_model=schemas.UserOut)
@router.patch("/users/me", response_model=schemas.UserOut)
def update_me(
    payload: schemas.UserUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    db_user = db.query(models.User).filter(models.User.id == current_user.id).first()
    if db_user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    if payload.email is not None:
        normalized_email = _normalize_email(payload.email)
        if normalized_email is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email is invalid")
        _ensure_unique_email(db, normalized_email, db_user.id)
        db_user.email = normalized_email

    if payload.username is not None:
        db_user.username = payload.username
    if payload.password is not None:
        db_user.password = utils.hash(payload.password)
    if payload.phone_number is not None:
        db_user.phone_number = payload.phone_number
    if payload.date_of_birth is not None:
        db_user.date_of_birth = payload.date_of_birth
    if payload.age is not None:
        db_user.age = payload.age
    if payload.height is not None:
        db_user.height = payload.height
    if payload.weight is not None:
        db_user.weight = payload.weight
    if payload.role is not None and payload.role.lower().strip() != db_user.role:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Role changes are not allowed here")

    if payload.doctor_id is not None:
        doctor = db.query(models.User).filter(models.User.id == payload.doctor_id).first()
        if doctor is None or doctor.role != "doctor":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Doctor not found")
        db_user.doc_id = doctor.id

    db.commit()
    db.refresh(db_user)
    return db_user


@router.get("/users/{id}", response_model=schemas.UserOut)
def get_user(
    id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(oauth2.get_current_user),
):
    user = db.query(models.User).filter(models.User.id == id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"user with id:{id} does not exist")
    if current_user.id == user.id:
        return user
    if current_user.role == "doctor" and user.doc_id == current_user.id:
        return user
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="not authorized to access this user")
