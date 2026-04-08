
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, constr


class PostBase(BaseModel):
    title:str 
    content:str
    published:bool = True

class PostCreate(PostBase):
    pass

class Post(PostBase):
    id : int
    created_at : datetime

class UserCreate(BaseModel):
    username : str
    email:EmailStr
    password: str
    role : str
    phone_number : str
    date_of_birth : str
    doctor_name: str = "None"
    doctor_email: str = "None"
    doctor_phone: str = "None"
    emergency_name: str = "None"
    emergency_email:str = "None"
    emergency_phone: str = "None"
    


    
class UserOut(BaseModel):
    id: int
    username: str
    email: EmailStr
    role: str
    phone_number: str
    date_of_birth: str

    class Config:
        from_attributes = True


class UserLogin(BaseModel):
    email:EmailStr
    password:str

class Token(BaseModel):
    access_token:str
    token_type:str

class TokenData(BaseModel):
    id:Optional[str] = None

class Vote (BaseModel):
    post_id: int
    dir: conint(le=1)

class Contact(BaseModel):
    name: str
    type: str
    phone: str
    email: str

class ContactOut(BaseModel):
    name: str
    id : int
    type: str
    phone: str
    email: str

    class Config:
        from_attributes = True

class Patient(BaseModel):
    name: str
    type: str
    phone: str
    email: str

class PatientOut(BaseModel):
    name: str
    id : int
    type: str
    phone: str
    email: str

    class Config:
        from_attributes = True


class Reminder(BaseModel):
    title : str
    type: str
    date: str
    time_hour: int
    time_minute: int
    frequency: str
    notes: str

class ReminderOut(BaseModel):
    title : str
    id : int
    type: str
    date: datetime
    time_hour: int
    time_minute: int
    frequency: str
    notes: str

    class Config:
        from_attributes = True

