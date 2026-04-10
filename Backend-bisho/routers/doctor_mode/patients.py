from fastapi import Depends, FastAPI , status , HTTPException , Response , APIRouter
from routers import oauth2
import app.schemas as schemas , app.database as database , app.models as models
from sqlalchemy.orm import Session
from typing import List




router = APIRouter(prefix="/patients" , tags=['Patients'])

@router.post("/createpatients",status_code = status.HTTP_201_CREATED,response_model = schemas.PatientOut)
def create_patient(patient: schemas.Patient, db:Session = Depends(database.get_db), current_user:int= Depends(oauth2.get_current_user)):
    new_patient = models.User(
        doc_id = current_user.id , role = "patient" , is_registered=False , **patient.dict())
    db.add(new_patient)
    db.commit()
    db.refresh(new_patient)
    return new_patient

@router.get("/")
def get_patients(db:Session = Depends(database.get_db),current_user:int = Depends(oauth2.get_current_user)):
    patients = db.query(models.User).filter(models.User.doc_id==current_user.id).all()
    return patients

@router.get("/{id}",response_model=schemas.PatientOut)
def get_patient(id: int, db:Session = Depends(database.get_db),current_user:int = Depends(oauth2.get_current_user)):
    patient = db.query(models.User).filter(models.User.id == id).first()
    if not patient:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    return patient



@router.put("/{id}")
def update_contact(
    id:int, updated_contact : schemas.Contact, db:Session = Depends(database.get_db),
    current_user:int= Depends(oauth2.get_current_user)):
    
    patient_query = db.query(models.User).filter(models.User.id==id)
    patient = patient_query.first()
    if patient == None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    
    patient_query.update(updated_contact.dict(),synchronize_session=False)

    db.commit()
       
    return patient_query.first()


@router.delete("/{id}",status_code=status.HTTP_204_NO_CONTENT)
def delete_patient(id:int, db:Session= Depends(database.get_db),current_user:int = Depends(oauth2.get_current_user)):
    patient_query = db.query(models.User).filter(models.User.id == id )
    patient = patient_query.first()

    if not patient : 
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    if (patient.owner_id != current_user.id):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)
    
    patient_query.delete(synchronize_session=False)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
