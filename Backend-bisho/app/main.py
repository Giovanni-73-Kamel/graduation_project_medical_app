
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI 
from app.database import engine
import app.models as models
from app.services.analysis_worker import start_analysis_worker, stop_analysis_worker
from routers import admin, catalog, ecg_pipeline, lab_results, medical_records, post, prescriptions, user , auth ,vote
import bcrypt

from routers.doctor_mode import appointments, doctors, patients
from routers.patient_mode import chat, contact, reminder

logging.basicConfig(level=logging.INFO)

# models.Base.metadata.create_all(bind=engine) 


@asynccontextmanager
async def lifespan(app: FastAPI):
    start_analysis_worker()
    try:
        yield
    finally:
        stop_analysis_worker()


app = FastAPI(lifespan=lifespan)
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
    allow_origin_regex=r"^http://(localhost|127\.0\.0\.1):\d+$",
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
app.include_router(doctors.router)
app.include_router(appointments.router)
app.include_router(ecg_pipeline.router)
app.include_router(medical_records.router)
app.include_router(prescriptions.router)
app.include_router(lab_results.router)
app.include_router(catalog.clinics_router)
app.include_router(catalog.medications_router)
app.include_router(admin.router)


@app.get("/")
async def root():
    return {"message": "Hello to Our Medical App !!"}

