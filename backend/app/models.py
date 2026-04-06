from datetime import datetime
from sqlalchemy import (
    Column, Integer, String, Date, Text, TIMESTAMP, ForeignKey, Table
)
from sqlalchemy.orm import relationship, declarative_base

Base = declarative_base()

class User(Base):
    __tablename__ = 'users'

    user_id = Column(Integer, primary_key=True)
    username = Column(String(255), unique=True, nullable=True) # Added for greeting
    email = Column(String(255), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(50))
    phone_number = Column(String(50), nullable=True) # Added for details
    date_of_birth = Column(Date, nullable=True) # Added for Age calculation
    created_at = Column(TIMESTAMP, default=datetime.utcnow)

    patients = relationship('Patient', back_populates='user', cascade="all, delete")
    doctors = relationship('Doctor', back_populates='user', cascade="all, delete")


class Clinic(Base):
    __tablename__ = 'clinics'

    clinic_id = Column(Integer, primary_key=True)
    name = Column(String(255), nullable=False)
    address = Column(String(255))
    phone = Column(String(50))

    patients = relationship('Patient', back_populates='clinic')
    doctors = relationship('Doctor', back_populates='clinic')
    appointments = relationship('Appointment', back_populates='clinic')


class Patient(Base):
    __tablename__ = 'patients'

    patient_id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.user_id', ondelete='CASCADE'))
    clinic_id = Column(Integer, ForeignKey('clinics.clinic_id', ondelete='SET NULL'))
    full_name = Column(String(255))
    date_of_birth = Column(Date)
    gender = Column(String(20))
    phone = Column(String(50))
    address = Column(String(255))
    emergency_contact = Column(String(255))
    insurance_info = Column(String(255))

    user = relationship('User', back_populates='patients')
    clinic = relationship('Clinic', back_populates='patients')
    medical_records = relationship('MedicalRecord', back_populates='patient', cascade="all, delete")
    appointments = relationship('Appointment', back_populates='patient', cascade="all, delete")
    doctors = relationship('Doctor', secondary='doctor_patient', back_populates='patients')


class Doctor(Base):
    __tablename__ = 'doctors'

    doctor_id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.user_id', ondelete='CASCADE'))
    clinic_id = Column(Integer, ForeignKey('clinics.clinic_id', ondelete='SET NULL'))
    specialization = Column(String(255))
    license_number = Column(String(255))
    department = Column(String(255))
    availability_schedule = Column(Text)
    max_patients = Column(Integer)

    user = relationship('User', back_populates='doctors')
    clinic = relationship('Clinic', back_populates='doctors')
    patients = relationship('Patient', secondary='doctor_patient', back_populates='doctors')
    appointments = relationship('Appointment', back_populates='doctor', cascade="all, delete")
    prescriptions = relationship('Prescription', back_populates='doctor', cascade="all, delete")


doctor_patient_table = Table(
    'doctor_patient', Base.metadata,
    Column('doctor_id', Integer, ForeignKey('doctors.doctor_id', ondelete='CASCADE'), primary_key=True),
    Column('patient_id', Integer, ForeignKey('patients.patient_id', ondelete='CASCADE'), primary_key=True),
    Column('start_date', Date)
)


class MedicalRecord(Base):
    __tablename__ = 'medical_records'

    record_id = Column(Integer, primary_key=True)
    patient_id = Column(Integer, ForeignKey('patients.patient_id', ondelete='CASCADE'))
    heart_rate = Column(Integer)
    calories_burnt = Column(Integer)
    spo2 = Column(Integer)
    stress_level = Column(Integer)
    last_updated = Column(TIMESTAMP, default=datetime.utcnow)

    patient = relationship('Patient', back_populates='medical_records')


class Appointment(Base):
    __tablename__ = 'appointments'

    appointment_id = Column(Integer, primary_key=True)
    patient_id = Column(Integer, ForeignKey('patients.patient_id', ondelete='CASCADE'))
    doctor_id = Column(Integer, ForeignKey('doctors.doctor_id', ondelete='CASCADE'))
    clinic_id = Column(Integer, ForeignKey('clinics.clinic_id', ondelete='SET NULL'))
    appointment_time = Column(TIMESTAMP)
    mode = Column(String(50))
    status = Column(String(50))

    patient = relationship('Patient', back_populates='appointments')
    doctor = relationship('Doctor', back_populates='appointments')
    clinic = relationship('Clinic', back_populates='appointments')
    prescriptions = relationship('Prescription', back_populates='appointment', cascade="all, delete")
    lab_results = relationship('LabResult', back_populates='appointment', cascade="all, delete")


class Prescription(Base):
    __tablename__ = 'prescriptions'

    prescription_id = Column(Integer, primary_key=True)
    appointment_id = Column(Integer, ForeignKey('appointments.appointment_id', ondelete='CASCADE'))
    doctor_id = Column(Integer, ForeignKey('doctors.doctor_id', ondelete='CASCADE'))
    notes = Column(Text)
    created_at = Column(TIMESTAMP, default=datetime.utcnow)

    appointment = relationship('Appointment', back_populates='prescriptions')
    doctor = relationship('Doctor', back_populates='prescriptions')
    medications = relationship('Medication', secondary='prescription_medication', back_populates='prescriptions')


class Medication(Base):
    __tablename__ = 'medications'

    medication_id = Column(Integer, primary_key=True)
    name = Column(String(255))
    description = Column(Text)

    prescriptions = relationship('Prescription', secondary='prescription_medication', back_populates='medications')


prescription_medication_table = Table(
    'prescription_medication', Base.metadata,
    Column('prescription_id', Integer, ForeignKey('prescriptions.prescription_id', ondelete='CASCADE'), primary_key=True),
    Column('medication_id', Integer, ForeignKey('medications.medication_id', ondelete='CASCADE'), primary_key=True),
    Column('dosage', String(100)),
    Column('duration', String(100))
)


class LabResult(Base):
    __tablename__ = 'lab_results'

    lab_result_id = Column(Integer, primary_key=True)
    appointment_id = Column(Integer, ForeignKey('appointments.appointment_id', ondelete='CASCADE'))
    test_name = Column(String(255))
    result_value = Column(String(255))
    file_url = Column(String(255))
    created_at = Column(TIMESTAMP, default=datetime.utcnow)

    appointment = relationship('Appointment', back_populates='lab_results')


class Reminder(Base):
    __tablename__ = 'reminders'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.user_id', ondelete='CASCADE'), nullable=False)
    title = Column(String(255), nullable=False)
    type = Column(String(50), nullable=False)        # 'medicine' or 'appointment'
    date = Column(String(50), nullable=False)        # ISO8601 string e.g. "2026-02-25T00:00:00"
    time_hour = Column(Integer, nullable=False)
    time_minute = Column(Integer, nullable=False)
    frequency = Column(String(50), nullable=False)   # 'once', 'daily', 'weekly', 'monthly'
    notes = Column(Text, nullable=True)
    created_at = Column(TIMESTAMP, default=datetime.utcnow)

    user = relationship('User')


class Contact(Base):
    __tablename__ = 'contacts'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.user_id', ondelete='CASCADE'), nullable=False)
    name = Column(String(255), nullable=False)
    type = Column(String(50), nullable=False)        # 'Relative', 'Doctor', 'Other'
    phone = Column(String(50), nullable=False, default='')
    email = Column(String(255), nullable=False, default='')
    created_at = Column(TIMESTAMP, default=datetime.utcnow)

    user = relationship('User')




