from typing import Optional

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_hostname: str = "localhost"
    database_port: str = "5432"
    database_password: str = "postgres"
    database_name: str = "medical_app"
    database_username: str = "postgres"
    database_url: Optional[str] = None

    secret_key: str = "change-me-in-production"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    gemini_api_key: str = ""
    gemini_model_name: str = ""
    gemini_request_timeout_seconds: int = 20
    gemini_max_output_tokens: int = 512

    device_ingest_token: str = ""
    ai_model_timeout_seconds: int = 15
    ai_model_retry_attempts: int = 1
    cors_origins: str = "http://localhost:3000,http://127.0.0.1:8000,http://localhost:8000"

    ecg_model_dir: str = "../AI models/ecg_classifier_v31_deployment"
    morphology_model_dir: str = "../AI models/Morphological Heartbeat Arrhythmia Classifier"
    bp_model_dir: str = "../AI models/BP_Model_Vital_15_Meta"
    ecg_model_enabled: bool = True
    auto_analyze_on_upload: bool = False
    auto_analyze_min_samples: int = 100
    compact_invalid_reading_signals: bool = True
    max_raw_signal_samples_per_reading: int = 1250

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
