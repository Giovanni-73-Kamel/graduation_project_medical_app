from sqlalchemy import TIMESTAMP, Column, ForeignKey , Integer , String , Boolean, text
from database import Base
from sqlalchemy.orm import relationship

class Post(Base):
    __tablename__ = "posts"

    id = Column(Integer,primary_key=True,nullable=False )
    title = Column(String,nullable=False)
    content = Column(String,nullable=False)
    published = Column(Boolean, server_default='TRUE',nullable=False)
    created_at = Column(TIMESTAMP(timezone=True),nullable=False, server_default=text('now()'))
    owner_id = Column(Integer, ForeignKey("users.id",ondelete="CASCADE"),nullable=False)
    owner = relationship("User")


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, nullable=False,primary_key=True )
    username=Column(String, nullable=False, unique=True)
    email=Column(String, nullable=False, unique=True)
    password = Column(String, nullable=False)
    role=Column(String, nullable=False)
    created_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=text('now()'))
    phone_number=Column(String, nullable=False)
    date_of_birth=Column(String, nullable=False)
    doctor_name=Column(String,nullable=False)
    doctor_email=Column(String, nullable=False)
    doctor_phone=Column(String, nullable=False)
    emergency_name=Column(String,nullable=False)
    emergency_email=Column(String, nullable=False)
    emergency_phone=Column(String, nullable=False)





    # doctor_id = Column(Integer,ForeignKey("doctors.id", ondelete="SET NULL"))
    # doctor = relationship("Doctor")
    # emergency_id = Column(Integer,ForeignKey("emergencys.id",ondelete="CASCADE"),nullable=False)
    # emergency = relationship("Emergency")

class Vote(Base):
    __tablename__ = "votes"
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True) 
    post_id = Column(Integer, ForeignKey("posts.id", ondelete="CASCADE"), primary_key=True) 

class Doctor(Base):
    __tablename__ = "doctors"

    id = Column(Integer, nullable=False,primary_key=True )
    name=Column(String, nullable=False, unique=True)
    email=Column(String, nullable=False, unique=True)
    phone_number=Column(String, nullable=False, unique=False)


class Emergency(Base):
    __tablename__ = "emergencys"

    id = Column(Integer, nullable=False,primary_key=True )
    name=Column(String, nullable=False, unique=True)
    email=Column(String, nullable=False, unique=True)
    phone_number=Column(String, nullable=False, unique=False)

class Contact(Base) :
    __tablename__ = "contacts"

    id = Column(Integer, nullable=False,primary_key=True )
    name = Column(String,nullable=False)
    type = Column(String,nullable=False)
    phone = Column(String,nullable=False,unique=True)
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
    notes = Column(String,nullable=False)    
    created_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=text('now()'))
    owner_id = Column(Integer, ForeignKey("users.id",ondelete="CASCADE"),nullable=False)
