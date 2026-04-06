from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

SQLALCHEMY_DATABASE_URL = "postgresql://postgres:Bisho1234@localhost/Medical_App"

# Create engine
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    echo=True  # Set to False in production
)

# Create a configured "Session" class
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

# Base class for all models
Base = declarative_base()

# Dependency to get DB session (for FastAPI or any app)
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
