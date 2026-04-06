from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Import routers
from .routers import auth, users, admin, reminders, contacts

app = FastAPI(title="Clinic Management API")

# CORS settings (allow Flutter frontend)
origins = [
    "http://localhost:3000",  # if testing with local web frontend
    "http://127.0.0.1:3000",
    "*",  # temporarily allow all for testing
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router, prefix="/auth", tags=["Authentication"])
app.include_router(users.router, prefix="/users", tags=["Users"])
app.include_router(admin.router, prefix="/admin", tags=["Admin"])
app.include_router(reminders.router, prefix="/reminders", tags=["Reminders"])
app.include_router(contacts.router, prefix="/contacts", tags=["Contacts"])

# Root endpoint
@app.get("/")
def root():
    return {"message": "Clinic Management API is running"}
