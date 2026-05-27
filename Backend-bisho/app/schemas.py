
from datetime import datetime
import math
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, EmailStr, Field, conint, field_validator, model_validator


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
    age:    str = ""
    height: str = ""
    weight: str = ""
    doctor_name: str = "None"
    doctor_email: str = "None"
    doctor_phone: str = "None"
    emergency_name: str = "None"
    emergency_email:str = "None"
    emergency_phone: str = "None"


class UserUpdate(BaseModel):
    username: Optional[str] = None
    email: Optional[EmailStr] = None
    password: Optional[str] = None
    phone_number: Optional[str] = None
    date_of_birth: Optional[str] = None
    age: Optional[str] = None
    height: Optional[str] = None
    weight: Optional[str] = None
    doctor_id: Optional[int] = None
    role: Optional[str] = None

    class Config:
        extra = "forbid"


    
class UserOut(BaseModel):
    id: int
    username: str
    email: EmailStr
    role: str
    phone_number: str
    date_of_birth: str
    age:    Optional[str] = None
    height: Optional[str] = None
    weight: Optional[str] = None

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
    dir: conint(ge=0, le=1)

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
    username: str
    phone_number: str
    email: str

class PatientOut(BaseModel):
    username: str
    id : int
    phone_number: str
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
    date: str
    time_hour: int
    time_minute: int
    frequency: str
    notes: str

    class Config:
        from_attributes = True

class Appointment(BaseModel):
    patient_id: int
    date: str
    time_hour: int
    time_minute: int
    title: str
    
class AppointmentOut(BaseModel):
    id: int
    patient_id: int
    date: str
    time_hour: int
    time_minute: int
    title: str
    doctor_id: int
    class Config:
        from_attributes = True


class DeviceOut(BaseModel):
    id: int
    device_id: str
    label: Optional[str] = None
    firmware_version: Optional[str] = None
    metadata_json: Dict[str, Any] = Field(default_factory=dict)
    created_at: datetime
    last_seen_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class SessionCreate(BaseModel):
    device_id: str = Field(..., min_length=1, max_length=128)
    session_id: str = Field(..., min_length=1, max_length=128)
    sampling_rate: int = Field(250, ge=1, le=2000)
    status: str = Field("active", min_length=1, max_length=32)
    patient_id: Optional[int] = None
    started_at: Optional[datetime] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)


class SessionOut(BaseModel):
    id: int
    session_id: str
    device_id: str
    patient_id: Optional[int] = None
    sampling_rate: int
    status: str
    metadata_json: Dict[str, Any] = Field(default_factory=dict)
    started_at: datetime
    ended_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


class ReadingCreate(BaseModel):
    device_id: str = Field(..., min_length=1, max_length=128)
    session_id: str = Field(..., min_length=1, max_length=128)
    timestamp: datetime
    sampling_rate: int = Field(..., ge=1, le=2000)
    ecg: List[float] = Field(..., min_length=1, max_length=10000)
    ppg: List[float] = Field(..., min_length=1, max_length=10000)
    battery: Optional[int] = Field(None, ge=0, le=100)
    status: str = Field("active", min_length=1, max_length=32)
    metadata: Dict[str, Any] = Field(default_factory=dict)

    @field_validator("ecg", "ppg")
    @classmethod
    def validate_signal(cls, values: List[float]) -> List[float]:
        if not values:
            raise ValueError("signal array cannot be empty")
        if any(not math.isfinite(float(value)) for value in values):
            raise ValueError("signal values must be finite numbers")
        return [float(value) for value in values]

    @model_validator(mode="after")
    def validate_matching_signal_lengths(self) -> "ReadingCreate":
        if len(self.ecg) != len(self.ppg):
            raise ValueError("ecg and ppg arrays must have the same length")
        return self


class ReadingOut(BaseModel):
    id: int
    device_id: str
    session_id: str
    timestamp: datetime
    sampling_rate: int
    ecg: List[float]
    ppg: List[float]
    battery: Optional[int] = None
    status: str
    sample_count: int
    metadata_json: Dict[str, Any] = Field(default_factory=dict)
    received_at: datetime
    commands: List[Dict[str, Any]] = Field(default_factory=list)

    class Config:
        from_attributes = True


class AnalysisResultOut(BaseModel):
    id: int
    session_id: str
    model_name: str
    model_version: str
    status: str
    metrics: Dict[str, Any]
    signal_quality: Dict[str, Any]
    predictions: Dict[str, Any]
    alerts: List[Dict[str, Any]]
    disclaimer: str
    created_at: datetime

    class Config:
        from_attributes = True


class DeviceCommandPreview(BaseModel):
    command_type: str
    priority: str = "normal"
    reason: str
    message: str
    payload: Dict[str, Any] = Field(default_factory=dict)
