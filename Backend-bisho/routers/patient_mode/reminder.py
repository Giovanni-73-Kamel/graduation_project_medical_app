from fastapi import Depends, FastAPI , status , HTTPException , Response , APIRouter
from routers import oauth2
import app.schemas as schemas , app.database as database , app.models as models
from sqlalchemy.orm import Session
from typing import List


router = APIRouter(prefix="/reminders" , tags=['Reminder'])


@router.post("/createreminders",status_code=status.HTTP_201_CREATED,response_model=schemas.ReminderOut)
def create_reminder(
    reminder: schemas.Reminder, db:Session = Depends(database.get_db),
    current_user:int= Depends(oauth2.get_current_user)):

        new_reminder = models.Reminder(owner_id = current_user.id , **reminder.dict())
        db.add(new_reminder)
        db.commit()
        db.refresh(new_reminder)
        return new_reminder

@router.put("/{id}")
def update_reminder(
    id:int, updated_reminder : schemas.Reminder, db:Session = Depends(database.get_db),
    current_user:int= Depends(oauth2.get_current_user)):
    
    reminder_query = db.query(models.Reminder).filter(models.Reminder.id==id)
    reminder = reminder_query.first()
    if reminder == None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    
    reminder_query.update(updated_reminder.dict(),synchronize_session=False)

    db.commit()
       
    return updated_reminder


@router.get("/",response_model=List[schemas.ReminderOut])
def get_contacts(db:Session = Depends(database.get_db),current_user:int = Depends(oauth2.get_current_user)):
    reminders = db.query(models.Reminder).filter(models.Reminder.owner_id==current_user.id).all()
    return reminders

@router.delete("/deletereminder/{id}",status_code=status.HTTP_204_NO_CONTENT)
def delete_reminder(id:int, db:Session= Depends(database.get_db),current_user:int = Depends(oauth2.get_current_user)):
    reminder_query = db.query(models.Reminder).filter(models.Reminder.id == id )
    reminder = reminder_query.first()

    if not reminder : 
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    if (reminder.owner_id != current_user.id):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)
    
    reminder_query.delete(synchronize_session=False)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)



