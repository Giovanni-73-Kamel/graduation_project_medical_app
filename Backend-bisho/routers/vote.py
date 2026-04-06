from fastapi import Depends, FastAPI , status , HTTPException , Response , APIRouter
import database, schemas, main , models
from sqlalchemy.orm import Session
from routers import oauth2

router = APIRouter(prefix="/votes" , tags=['Vote'])

@router.post("/", status_code=status.HTTP_201_CREATED)
def vote (vote:schemas.Vote, db: Session= Depends(database.get_db), current_user: int= Depends(oauth2.get_current_user)):

    post = db.query(models.Post).filter(models.Post.id == vote.post_id).first()
    if not post :
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,detail=f"post with id : {vote.post_id} doesn't exist")
    vote_query= db.query(models.Vote).filter(models.Vote.post_id == vote.post_id, models.Vote.user_id == current_user.id)
    vote_found = vote_query.first()


    if (vote.dir == 1):
        if vote_found: raise HTTPException(status_code=status.HTTP_409_CONFLICT,detail=f"Current user with ID : {current_user.id} has already voted to post with id : {vote.post_id}")

        new_vote = models.Vote(user_id = current_user.id, post_id=vote.post_id)
        db.add(new_vote)
        db.commit()
        return {"message":"successfully added vote"}
    else:
        if not vote_found :
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,detail=f"Vote doesn't exist")
        vote_query.delete(synchronize_session=False)
        db.commit()
        return {"message":"Vote has been deleted successfully"}        

        