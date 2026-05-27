from sqlalchemy import (
    TIMESTAMP,
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    JSON,
    String,
    UniqueConstraint,
    text,
)
from app.database import Base
from sqlalchemy.orm import relationship

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, nullable=False,primary_key=True )
    username=Column(String, nullable=False, unique=True)
    email=Column(String, nullable=False, unique=True)
    password = Column(String, nullable=True)        #to permit non-users doctors & patients
    role=Column(String, nullable=False)
    created_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=text('now()'))
    phone_number=Column(String, nullable=False)
    date_of_birth=Column(String, nullable=True)
    age    = Column(String, nullable=True)
    height = Column(String, nullable=True)
    weight = Column(String, nullable=True)
    is_registered= Column(Boolean,nullable=False)
    doc_id = Column(Integer, ForeignKey("users.id",ondelete="SET NULL"),nullable=True)
    doctor = relationship("User", remote_side=[id])
    emergency_id = Column(Integer, ForeignKey("emergencys.id",ondelete="SET NULL"),nullable=True)
    emergency = relationship("Emergency", backref="users")

    
   

class Post(Base):
    __tablename__ = "posts"

    id = Column(Integer,primary_key=True,nullable=False )
    title = Column(String,nullable=False)
    content = Column(String,nullable=False)
    published = Column(Boolean, server_default='TRUE',nullable=False)
    created_at = Column(TIMESTAMP(timezone=True),nullable=False, server_default=text('now()'))
    owner_id = Column(Integer, ForeignKey("users.id",ondelete="CASCADE"),nullable=False)
    owner = relationship("User")



class Emergency(Base):
    __tablename__ = "emergencys"

    id = Column(Integer, nullable=False,primary_key=True )
    name=Column(String, nullable=False)
    email=Column(String, nullable=False)
    phone_number=Column(String, nullable=False)
    


class Vote(Base):
    __tablename__ = "votes"
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    post_id = Column(Integer, ForeignKey("posts.id", ondelete="CASCADE"), primary_key=True)


class Contact(Base) :
    __tablename__ = "contacts"

    id = Column(Integer, nullable=False,primary_key=True )
    name = Column(String,nullable=False)
    type = Column(String,nullable=False)
    phone = Column(String,nullable=False)
    email = Column(String,nullable=False)
    created_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=text('now()'))
    owner_id = Column(Integer, ForeignKey("users.id",ondelete="CASCADE"),nullable=False)

class Reminder(Base) :
    __tablename__ = "reminders"

    id = Column(Integer, nullable=False,primary_key=True )
    title = Column(String,nullable=False)
    type = Column(String,nullable=False)
    date = Column(String,nullable=False)
    time_hour = Column(Integer,nullable=False)
    time_minute = Column(Integer,nullable=False)
    frequency = Column(String,nullable=False) 
    notes = Column(String,nullable=True)    
    created_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=text('now()'))
    owner_id = Column(Integer, ForeignKey("users.id",ondelete="CASCADE"),nullable=False)

class Appointment(Base):
    __tablename__ = "appointments"

    id = Column(Integer, nullable=False,primary_key=True )
    title = Column(String,nullable=False)
    doctor_id = Column(Integer, ForeignKey("users.id",ondelete="CASCADE"),nullable=False)
    patient_id = Column(Integer, ForeignKey("users.id",ondelete="CASCADE"),nullable=False)
    date = Column(String,nullable=False)
    time_hour = Column(Integer,nullable=False)
    time_minute = Column(Integer,nullable=False)
    notes = Column(String,nullable=True)    
    created_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=text('now()'))


class Device(Base):
    __tablename__ = "devices"

    id = Column(Integer, primary_key=True, nullable=False)
    device_id = Column(String, nullable=False, unique=True, index=True)
    label = Column(String, nullable=True)
    firmware_version = Column(String, nullable=True)
    metadata_json = Column(JSON, nullable=False, server_default=text("'{}'"))
    created_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=text("now()"))
    last_seen_at = Column(DateTime(timezone=True), nullable=True)

    sessions = relationship("MonitoringSession", back_populates="device")
    readings = relationship("RawReading", back_populates="device")


class MonitoringSession(Base):
    __tablename__ = "sessions"

    id = Column(Integer, primary_key=True, nullable=False)
    session_id = Column(String, nullable=False, unique=True, index=True)
    device_id = Column(String, ForeignKey("devices.device_id", ondelete="CASCADE"), nullable=False)
    patient_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    sampling_rate = Column(Integer, nullable=False)
    status = Column(String, nullable=False, server_default="active")
    metadata_json = Column(JSON, nullable=False, server_default=text("'{}'"))
    started_at = Column(DateTime(timezone=True), nullable=False)
    ended_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=text("now()"))

    device = relationship("Device", back_populates="sessions")
    patient = relationship("User")
    readings = relationship("RawReading", back_populates="session", cascade="all, delete-orphan")
    analysis_results = relationship(
        "AnalysisResult", back_populates="session", cascade="all, delete-orphan"
    )

    __table_args__ = (
        Index("ix_sessions_device_id", "device_id"),
        Index("ix_sessions_started_at", "started_at"),
    )


class RawReading(Base):
    __tablename__ = "raw_readings"

    id = Column(Integer, primary_key=True, nullable=False)
    device_id = Column(String, ForeignKey("devices.device_id", ondelete="CASCADE"), nullable=False)
    session_id = Column(String, ForeignKey("sessions.session_id", ondelete="CASCADE"), nullable=False)
    timestamp = Column(DateTime(timezone=True), nullable=False)
    sampling_rate = Column(Integer, nullable=False)
    ecg = Column(JSON, nullable=False)
    ppg = Column(JSON, nullable=False)
    battery = Column(Integer, nullable=True)
    status = Column(String, nullable=False, server_default="active")
    sample_count = Column(Integer, nullable=False)
    metadata_json = Column(JSON, nullable=False, server_default=text("'{}'"))
    received_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=text("now()"))

    device = relationship("Device", back_populates="readings")
    session = relationship("MonitoringSession", back_populates="readings")

    __table_args__ = (
        UniqueConstraint("session_id", "timestamp", name="uq_raw_readings_session_timestamp"),
        Index("ix_raw_readings_device_id", "device_id"),
        Index("ix_raw_readings_session_id", "session_id"),
        Index("ix_raw_readings_timestamp", "timestamp"),
    )


class AnalysisResult(Base):
    __tablename__ = "analysis_results"

    id = Column(Integer, primary_key=True, nullable=False)
    session_id = Column(String, ForeignKey("sessions.session_id", ondelete="CASCADE"), nullable=False)
    model_name = Column(String, nullable=False)
    model_version = Column(String, nullable=False)
    status = Column(String, nullable=False, server_default="completed")
    metrics = Column(JSON, nullable=False, server_default=text("'{}'"))
    signal_quality = Column(JSON, nullable=False, server_default=text("'{}'"))
    predictions = Column(JSON, nullable=False, server_default=text("'{}'"))
    alerts = Column(JSON, nullable=False, server_default=text("'[]'"))
    disclaimer = Column(
        String,
        nullable=False,
        server_default="Decision-support only, not a final medical diagnosis.",
    )
    created_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=text("now()"))

    session = relationship("MonitoringSession", back_populates="analysis_results")

    __table_args__ = (
        Index("ix_analysis_results_session_id", "session_id"),
        Index("ix_analysis_results_created_at", "created_at"),
    )
