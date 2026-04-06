from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from ..database import SessionLocal
from ..models import User
from ..routers.auth import get_current_user
from ..utils import hash_password

router = APIRouter()

# Dependency to get DB session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ---------------------------
# Get current user profile
# ---------------------------
@router.get("/me")
def read_current_user(current_user: User = Depends(get_current_user)):
    return {
        "user_id": current_user.user_id,
        "username": current_user.username,
        "email": current_user.email,
        "role": current_user.role,
        "phone_number": current_user.phone_number,
        "date_of_birth": current_user.date_of_birth.isoformat() if current_user.date_of_birth else None,
        "created_at": current_user.created_at
    }


# ---------------------------
# Create User (Registration)
# ---------------------------
class UserCreate(BaseModel):
    username: str
    email: EmailStr
    password: str
    role: str = "patient"
    phone_number: str | None = None
    date_of_birth: str | None = None # Format "YYYY-MM-DD"

@router.post("/", status_code=status.HTTP_201_CREATED)
def create_user(data: UserCreate, db: Session = Depends(get_db)):
    # Check if user already exists
    if db.query(User).filter(User.email == data.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")
    if db.query(User).filter(User.username == data.username).first():
        raise HTTPException(status_code=400, detail="Username already taken")
    
    dob = None
    if data.date_of_birth:
        try:
            dob = datetime.strptime(data.date_of_birth, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")

    new_user = User(
        username=data.username,
        email=data.email,
        password_hash=hash_password(data.password),
        role=data.role,
        phone_number=data.phone_number,
        date_of_birth=dob
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return {"message": "User created successfully", "user_id": new_user.user_id}


# ---------------------------
# Get all users (admin only)
# ---------------------------
@router.get("/", response_model=List[dict])
def read_users(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")
    
    users = db.query(User).all()
    return [
        {
            "user_id": user.user_id,
            "email": user.email,
            "role": user.role,
            "created_at": user.created_at
        }
        for user in users
    ]


# ---------------------------
# Update current user info
# ---------------------------
from pydantic import BaseModel, EmailStr

class UpdateUser(BaseModel):
    username: str | None = None
    email: EmailStr | None = None
    role: str | None = None
    phone_number: str | None = None
    date_of_birth: str | None = None

@router.put("/me")
def update_current_user(data: UpdateUser, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if data.username:
        current_user.username = data.username
    if data.email:
        current_user.email = data.email
    if data.role:
        current_user.role = data.role
    if data.phone_number:
        current_user.phone_number = data.phone_number
    if data.date_of_birth:
        try:
            current_user.date_of_birth = datetime.strptime(data.date_of_birth, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
            
    db.commit()
    db.refresh(current_user)
    return {
        "message": "User updated successfully",
        "user": {
            "user_id": current_user.user_id,
            "email": current_user.email,
            "role": current_user.role
        }
    }
