from fastapi import Depends, FastAPI , status , HTTPException , Response , APIRouter
from routers import oauth2
import app.schemas as schemas , app.database as database , app.models as models
from sqlalchemy.orm import Session
from typing import List




router = APIRouter(prefix="/appointments" , tags=['Appointments'])

@router.post("/createappointment/",status_code = status.HTTP_201_CREATED)
def create_appointment(appointment: schemas.Appointment, db:Session = Depends(database.get_db), current_user:int= Depends(oauth2.get_current_user)):
    new_appointment = models.Appointment(
        doctor_id = current_user.id , **appointment.dict())
    
    db.add(new_appointment)
    db.flush()
    
    new_reminder = models.Reminder(
        owner_id = appointment.patient_id,
        title = appointment.title,
        type = "Appointment",
        date = appointment.date,
        time_hour = appointment.time_hour,
        time_minute = appointment.time_minute,
        frequency = "Once",
        notes = f"Appointment with doctor id {current_user.id}"
    )
    db.add(new_reminder)
    
    
    db.commit()
    db.refresh(new_appointment)
    
    # Return response matching AppointmentOut schema
    response_data = {
        "id": new_appointment.id,
        "patient_id": new_appointment.patient_id,
        "date": new_appointment.date,
        "time_hour": new_appointment.time_hour,
        "time_minute": new_appointment.time_minute,
        "title": new_appointment.title,
        "doctor_id": new_appointment.doctor_id
    }
    return response_data

@router.get("/")
def get_appointments(db:Session = Depends(database.get_db),current_user:int = Depends(oauth2.get_current_user)):
    appointments = db.query(models.Appointment, models.User).join(
        models.User, models.Appointment.patient_id == models.User.id
    ).filter(models.Appointment.doctor_id==current_user.id).all()
    
    result = []
    for appointment, patient in appointments:
        time_str = f"{appointment.time_hour:02d}:{appointment.time_minute:02d}"
        result.append({
            "id": appointment.id,
            "patient_id": appointment.patient_id,
            "patient_name": patient.username,
            "date": appointment.date,
            "time_hour": appointment.time_hour,
            "time_minute": appointment.time_minute,
            "time": time_str,
            "title": appointment.title
        })
    
    # Sort by date and time (nearest first)
    result.sort(key=lambda x: (x["date"], x["time_hour"], x["time_minute"]))
    
    return result

@router.get("/{id}",response_model=schemas.AppointmentOut)
def get_appointment(id: int, db:Session = Depends(database.get_db),current_user:int = Depends(oauth2.get_current_user)):
    appointment = db.query(models.Appointment).filter(models.Appointment.id == id).first()
    if not appointment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    return appointment



@router.put("/{id}")
def update_appointment(
    id:int, updated_appointment : schemas.Appointment, db:Session = Depends(database.get_db),
    current_user:int= Depends(oauth2.get_current_user)):
    
    appointment_query = db.query(models.Appointment).filter(models.Appointment.id==id)
    appointment = appointment_query.first()
    if appointment == None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    
    appointment_query.update(updated_appointment.dict(),synchronize_session=False)

    db.commit()
       
    return appointment_query.first()


@router.delete("/{id}",status_code=status.HTTP_204_NO_CONTENT)
def delete_appointment(id:int, db:Session= Depends(database.get_db),current_user:int = Depends(oauth2.get_current_user)):
    appointment_query = db.query(models.Appointment).filter(models.Appointment.id == id )
    appointment = appointment_query.first()

    if not appointment : 
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    if (appointment.doctor_id != current_user.id):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)
    
    appointment_query.delete(synchronize_session=False)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
