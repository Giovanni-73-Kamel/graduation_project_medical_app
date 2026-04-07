
from fastapi import FastAPI 
from database import engine
import models
from routers import post, user , auth ,contact, vote , reminder , chat
import bcrypt


models.Base.metadata.create_all(bind=engine) 

app = FastAPI()
print(bcrypt.__version__)  # should print a version like 4.x

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(post.router)
app.include_router(user.router)
app.include_router(auth.router)
app.include_router(vote.router)
app.include_router(reminder.router)
app.include_router(contact.router)
app.include_router(chat.router)




@app.get("/")
async def root():
    return {"message": "Hello World"}

