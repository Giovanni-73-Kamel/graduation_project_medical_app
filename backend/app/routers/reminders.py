from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, List

from ..database import SessionLocal
from ..models import Reminder
from ..routers.auth import get_current_user

router = APIRouter()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ----- Pydantic Schemas -----

class ReminderCreate(BaseModel):
    title: str
    type: str           # 'medicine' or 'appointment'
    date: str           # ISO8601 string
    time_hour: int
    time_minute: int
    frequency: str      # 'once', 'daily', 'weekly', 'monthly'
    notes: Optional[str] = None


class ReminderUpdate(BaseModel):
    title: Optional[str] = None
    type: Optional[str] = None
    date: Optional[str] = None
    time_hour: Optional[int] = None
    time_minute: Optional[int] = None
    frequency: Optional[str] = None
    notes: Optional[str] = None


# ----- Endpoints -----

@router.get("/", response_model=List[dict])
def get_reminders(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Return all reminders belonging to the current user."""
    reminders = db.query(Reminder).filter(Reminder.user_id == current_user.user_id).all()
    return [
        {
            "id": r.id,
            "title": r.title,
            "type": r.type,
            "date": r.date,
            "time_hour": r.time_hour,
            "time_minute": r.time_minute,
            "frequency": r.frequency,
            "notes": r.notes,
        }
        for r in reminders
    ]


@router.post("/", status_code=status.HTTP_201_CREATED)
def create_reminder(
    data: ReminderCreate,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new reminder for the current user."""
    reminder = Reminder(
        user_id=current_user.user_id,
        title=data.title,
        type=data.type,
        date=data.date,
        time_hour=data.time_hour,
        time_minute=data.time_minute,
        frequency=data.frequency,
        notes=data.notes,
    )
    db.add(reminder)
    db.commit()
    db.refresh(reminder)
    return {"id": reminder.id, "message": "Reminder created"}


@router.put("/{reminder_id}", status_code=status.HTTP_204_NO_CONTENT)
def update_reminder(
    reminder_id: int,
    data: ReminderUpdate,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update an existing reminder (must belong to current user)."""
    reminder = db.query(Reminder).filter(
        Reminder.id == reminder_id,
        Reminder.user_id == current_user.user_id
    ).first()

    if not reminder:
        raise HTTPException(status_code=404, detail="Reminder not found")

    if data.title is not None:
        reminder.title = data.title
    if data.type is not None:
        reminder.type = data.type
    if data.date is not None:
        reminder.date = data.date
    if data.time_hour is not None:
        reminder.time_hour = data.time_hour
    if data.time_minute is not None:
        reminder.time_minute = data.time_minute
    if data.frequency is not None:
        reminder.frequency = data.frequency
    if data.notes is not None:
        reminder.notes = data.notes

    db.commit()


@router.delete("/{reminder_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_reminder(
    reminder_id: int,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete a reminder (must belong to current user)."""
    reminder = db.query(Reminder).filter(
        Reminder.id == reminder_id,
        Reminder.user_id == current_user.user_id
    ).first()

    if not reminder:
        raise HTTPException(status_code=404, detail="Reminder not found")

    db.delete(reminder)
    db.commit()
