import models, schemas
from fastapi import Depends, FastAPI , status , HTTPException , Response , APIRouter
from sqlalchemy.orm import Session
from database import get_db
from typing import List
from routers import oauth2
router = APIRouter()

@router.get("/posts",response_model=List[schemas.Post])
def get_posts(db: Session = Depends(get_db),current_user:int = Depends(oauth2.get_current_user),limit:int = 10, skip:int=0, search : str = "" ):

    #cursor.execute("""SELECT * FROM posts""")
    #posts =cursor.fetchall()
    print(current_user.email)
    posts = db.query(models.Post).filter(models.Post.title.contains(search)).limit(limit).offset(skip).all()
    return posts

@router.post("/createposts" , status_code=status.HTTP_201_CREATED,response_model=schemas.Post)
def create_posts(post : schemas.PostCreate, db:Session = Depends(get_db), current_user:int= Depends(oauth2.get_current_user)):
    print (current_user)
    # #place holders are helded instead of f string to avoid SQL injection
    # cursor.execute("""INSERT INTO posts (title, content, published) VALUES (%s, %s, %s) RETURNING * """,(post.title,post.content,post.published))
    # # the order of the inputs have a critical impact in output:different order other than in DB causes errors
    # new_post= cursor.fetchone()
    # conn.commit()
    new_post= models.Post(owner_id = current_user.id,**post.dict()) 
    db.add(new_post)
    db.commit()
    db.refresh(new_post)  
    return new_post

@router.get("/posts/{id}",response_model=schemas.Post)
def get_post(id: int, db:Session = Depends(get_db), current_user :int= Depends(oauth2.get_current_user)):
    # cursor.execute("""SELECT * FROM posts WHERE id = %s  """ , (str(id),) )
    # post = cursor.fetchone()
    post = db.query(models.Post).filter(models.Post.id == id).first()

    
    if not post:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"post with id: {id} was not found")
    return post

@router.delete("/posts/{id}", status_code = status.HTTP_204_NO_CONTENT)
def delete_post (id : int, db: Session = Depends(get_db), current_user:int= Depends(oauth2.get_current_user)):
    
    # cursor.execute("""DELETE FROM posts WHERE id= %s RETURNING *""",(str(id),))
    # deleted_post = cursor.fetchone()
    # conn.commit()

    post_query = db.query(models.Post).filter(models.Post.id == id)
    post = post_query.first()

    if post == None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,detail=f"post with id : {id} was not found")
    
    if post.owner_id != current_user.id :
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,detail=f"not authorized to perform requested action!")

    post_query.delete(synchronize_session=False)
    db.commit()
    return Response(status_code = status.HTTP_204_NO_CONTENT)

@router.put("/posts/{id}",response_model=schemas.Post)
def update_post(id:int , updated_post:schemas.PostCreate , db: Session = Depends(get_db), current_user:int= Depends(oauth2.get_current_user)):
    
    # cursor.execute("""UPDATE posts SET title = %s , content= %s,published=%s WHERE id = %s  RETURNING * """,(post.title , post.content, post.published,str(id),))
    # updated_post = cursor.fetchone()
    # conn.commit()

    post_query = db.query(models.Post).filter(models.Post.id == id)
    post = post_query.first()

    if post == None:
        raise HTTPException(status_code= status.HTTP_404_NOT_FOUND , detail= f"The post with ID : {id} is not found")
    
    if post.owner_id != current_user.id :
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,detail=f"not authorized to perform requested action!")


    post_query.update(updated_post.dict(),synchronize_session=False)

    db.commit()

    return post_query.first()

