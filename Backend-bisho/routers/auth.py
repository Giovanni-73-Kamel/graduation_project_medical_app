from fastapi import APIRouter, Depends , status , Response , HTTPException 
from sqlalchemy.orm import Session
import app.schemas as schemas , app.models as models , app.utils as utils
from app.database import get_db
from routers import oauth2
from fastapi.security import OAuth2PasswordRequestForm 
from jose import JWTError , jwt


router = APIRouter(tags=['Authentication'])


@router.post("/login/", response_model=schemas.Token)
def login(login_credintials:OAuth2PasswordRequestForm = Depends(),db:Session= Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == login_credintials.username).first()
    if not user : 
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,detail=f"invalid credintials")
    if not utils.verify(login_credintials.password,user.password):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,detail=f"invalid credintials")
    
    token = oauth2.create_access_token(data={"user_id": user.id})
    return {"access_token" : token,
            "token_type": "bearer"
            }

