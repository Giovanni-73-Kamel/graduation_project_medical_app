
import logging

from fastapi import FastAPI 
from app.database import engine
import app.models as models
from routers import ecg_pipeline, post, user , auth ,vote
import bcrypt

from routers.doctor_mode import appointments, patients
from routers.patient_mode import chat, contact, reminder

logging.basicConfig(level=logging.INFO)

# models.Base.metadata.create_all(bind=engine) 

app = FastAPI()
# print(bcrypt.__version__)  # should print a version like 4.x

from fastapi.middleware.cors import CORSMiddleware
from app.config import settings

allowed_origins = [
    origin.strip()
    for origin in settings.cors_origins.split(",")
    if origin.strip()
]
if not allowed_origins:
    allowed_origins = ["http://localhost:3000", "http://127.0.0.1:8000"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
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
app.include_router(patients.router)
app.include_router(appointments.router)
app.include_router(ecg_pipeline.router)





@app.get("/")
async def root():
    return {"message": "Hello to Our Medical App !!"}

