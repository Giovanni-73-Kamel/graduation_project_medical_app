import app.models as models, app.schemas as schemas, app.utils as utils
from fastapi import Depends, FastAPI , status , HTTPException , Response , APIRouter
from sqlalchemy.orm import Session
from routers import oauth2
from app.database import get_db

router = APIRouter()

@router.post("/users/", status_code=status.HTTP_201_CREATED, response_model=schemas.UserOut)
def create_user (user:schemas.UserCreate, db:Session=Depends(get_db)):
   
    existing_user = db.query(models.User).filter(
        models.User.email == user.email.lower().strip() , models.User.is_registered == True
        ).first()
    if existing_user :
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="User with this email already exists"
            )
   
    hashed_password = utils.hash(user.password)
    user.password = hashed_password
    if (user.role == "patient"):
        doc_email = user.doctor_email.lower().strip()
        doc = db.query(models.User).filter(models.User.email == doc_email).first()
        
        if doc and doc.role != "doctor":
            raise HTTPException(
                status_code=400, detail="Provided doctor email is not a doctor"
                )
        
        if not doc:
            doc = models.User(
                username = user.doctor_name,
                email = doc_email,
                phone_number = user.doctor_phone,
                role = "doctor",
                is_registered = False
            )
            db.add(doc)
            db.flush()
            
        
        
        emerg_email = user.emergency_email.lower().strip()
        emerg = db.query(models.Emergency).filter(models.Emergency.email == emerg_email).first()

        
        if not emerg:
            emerg = models.Emergency(
                name = user.emergency_name,
                email = emerg_email,
                phone_number = user.emergency_phone
                
            )
            db.add(emerg)
            db.flush()
            

        new_user = models.User(
            username = user.username,
            email = user.email.lower().strip(),
            password = user.password,
            role = user.role,
            phone_number = user.phone_number,
            date_of_birth = user.date_of_birth,
            age = user.age,
            height = user.height,
            weight = user.weight,
            doc_id = doc.id,
            emergency_id = emerg.id,
            is_registered = True 
        )
        
        db.add(new_user)
        db.flush()
        
        
            
        doc_contact = models.Contact(
            owner_id=new_user.id,
            name=user.doctor_name,
            email=doc_email,
            phone=user.doctor_phone,
            type="doctor"
        )
        
        
        emerg_contact = models.Contact(
            owner_id=new_user.id,
            name=user.emergency_name,
            email=emerg_email,
            phone=user.emergency_phone,
            type="emergency"
        )
        db.add_all([doc_contact,emerg_contact])
        
    elif (user.role == "doctor"):
        stored_doc_query = db.query(models.User).filter(models.User.email == user.email.lower().strip())
        stored_doc = stored_doc_query.first()
        if stored_doc:
            stored_doc_query.update({
                "username": user.username,
                "email": user.email.lower().strip(),
                "password": user.password,
                "role": "doctor",
                "phone_number": user.phone_number,
                "date_of_birth": user.date_of_birth,
                "age": user.age,
                "height": user.height,
                "weight": user.weight,
                "is_registered": True
            }, synchronize_session=False)
            db.flush()
            new_user = db.query(models.User).filter(models.User.email == user.email.lower().strip()).first()
            
        else:
            new_user = models.User(
                username=user.username,
                email=user.email.lower().strip(),
                password=user.password,
                role="doctor",
                phone_number=user.phone_number,
                date_of_birth=user.date_of_birth,
                age=user.age,
                height=user.height,
                weight=user.weight,
                is_registered=True
            )
            db.add(new_user)
            
    
    else:
        raise HTTPException(status_code=400, detail="Invalid role")
    db.commit()
    db.refresh(new_user)
    return new_user

@router.get("/users/me", response_model=schemas.UserOut)
def get_me(current_user = Depends(oauth2.get_current_user)):
    return current_user

@router.get("/users/{id}", response_model=schemas.UserOut)
def get_user (id:int, db:Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == id).first()
    if not user : 
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,detail=f"user with id:{id} does not exist")


    return user