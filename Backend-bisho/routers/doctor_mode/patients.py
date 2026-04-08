from fastapi import Depends, FastAPI , status , HTTPException , Response , APIRouter
from routers import oauth2
import app.schemas as schemas , app.database as database , app.models as models
from sqlalchemy.orm import Session
from typing import List




router = APIRouter(prefix="/patients" , tags=['Contact'])

@router.post("/createpatient",status_code = status.HTTP_201_CREATED,response_model = schemas.PatientOut)
def create_contact(contact: schemas.Contact, db:Session = Depends(database.get_db), current_user:int= Depends(oauth2.get_current_user)):
    new_contact = models.Contact(owner_id = current_user.id , **contact.dict())
    db.add(new_contact)
    db.commit()
    db.refresh(new_contact)
    return new_contact

@router.get("/",response_model=List[schemas.ContactOut])
def get_contacts(db:Session = Depends(database.get_db),current_user:int = Depends(oauth2.get_current_user)):
    contacts = db.query(models.Contact).filter(models.Contact.owner_id==current_user.id).all()
    return contacts


@router.put("/{id}")
def update_contact(
    id:int, updated_contact : schemas.Contact, db:Session = Depends(database.get_db),
    current_user:int= Depends(oauth2.get_current_user)):
    
    contact_query = db.query(models.Contact).filter(models.Contact.id==id)
    contact = contact_query.first()
    if contact == None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    
    contact_query.update(updated_contact.dict(),synchronize_session=False)

    db.commit()
       
    return updated_contact


@router.delete("/{id}",status_code=status.HTTP_204_NO_CONTENT)
def delete_contact(id:int, db:Session= Depends(database.get_db),current_user:int = Depends(oauth2.get_current_user)):
    contact_query = db.query(models.Contact).filter(models.Contact.id == id )
    contact = contact_query.first()

    if not contact : 
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    if (contact.owner_id != current_user.id):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)
    
    contact_query.delete(synchronize_session=False)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
