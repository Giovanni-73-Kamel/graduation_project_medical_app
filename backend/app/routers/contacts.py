from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List

from ..database import SessionLocal
from ..models import Contact
from ..routers.auth import get_current_user

router = APIRouter()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ----- Pydantic Schemas -----

class ContactCreate(BaseModel):
    name: str
    type: str       # 'Relative', 'Doctor', 'Other'
    phone: str = ''
    email: str = ''


# ----- Endpoints -----

@router.get("/", response_model=List[dict])
def get_contacts(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Return all contacts belonging to the current user."""
    contacts = db.query(Contact).filter(Contact.user_id == current_user.user_id).all()
    return [
        {
            "id": c.id,
            "name": c.name,
            "type": c.type,
            "phone": c.phone,
            "email": c.email,
        }
        for c in contacts
    ]


@router.post("/", status_code=status.HTTP_201_CREATED)
def create_contact(
    data: ContactCreate,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new contact for the current user."""
    contact = Contact(
        user_id=current_user.user_id,
        name=data.name,
        type=data.type,
        phone=data.phone,
        email=data.email,
    )
    db.add(contact)
    db.commit()
    db.refresh(contact)
    return {"id": contact.id, "message": "Contact created"}


@router.delete("/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_contact(
    contact_id: int,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete a contact (must belong to current user)."""
    contact = db.query(Contact).filter(
        Contact.id == contact_id,
        Contact.user_id == current_user.user_id
    ).first()

    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")

    db.delete(contact)
    db.commit()
