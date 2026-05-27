from __future__ import annotations

from datetime import datetime, timezone
from types import SimpleNamespace

import pytest

from app.services.ai_inference import InferenceService
from app.services.ai_prompts import CHAT_PROMPT_VERSION, CHAT_PROMPT_V1
from app.services.chat_service import MedicalChatService


def _reading(timestamp: datetime, ecg: list[float], ppg: list[float]) -> SimpleNamespace:
    return SimpleNamespace(
        timestamp=timestamp,
        sampling_rate=250,
        ecg=ecg,
        ppg=ppg,
    )


def test_ai_model_registry_lists_three_models():
    service = InferenceService()
    metadata = service.metadata()

    names = {item["name"] for item in metadata}
    assert names == {
        "ecg_arrhythmia_v31",
        "morphology_heartbeat_v1",
        "bp_vital_meta",
    }


def test_ai_service_normalizes_model_outputs(monkeypatch):
    service = InferenceService()
    service.ecg_adapter.predict = lambda ecg: {
        "model_available": True,
        "classes": {
            "NORM": {"detected": True, "probability": 0.91, "confidence": 0.88, "threshold": 0.49},
            "MI": {"detected": False, "probability": 0.02, "confidence": 0.01, "threshold": 0.42},
        },
    }
    service.morphology_adapter.predict = lambda ecg: {
        "model_available": True,
        "classes": {
            "Normal": {"detected": True, "probability": 0.9, "confidence": 0.85, "threshold": 0.05},
        },
    }
    service.bp_adapter.predict = lambda ppg, sampling_rate, patient=None: {
        "model_available": True,
        "systolic_mmHg": 120.0,
        "diastolic_mmHg": 80.0,
        "confidence": 0.76,
        "meta_vector": {"weight": 70.0, "height": 175.0, "bmi": 22.9},
    }

    ecg = [0.0] * 200
    ppg = [1.0] * 200
    for index in (20, 70, 120, 170):
        ecg[index] = 1.5
        ppg[index] = 2.0

    result = service.analyze(
        [
            _reading(datetime.now(timezone.utc), ecg, ppg),
            _reading(datetime.now(timezone.utc), ecg, ppg),
        ]
    )

    models = result["predictions"]["models"]
    assert models["ecg_arrhythmia_v31"]["status"] == "completed"
    assert models["blood_pressure_vital_meta"]["systolic_mmHg"] == 120.0
    assert result["status"] == "completed"


def test_chat_prompt_version_is_named():
    assert CHAT_PROMPT_VERSION == "medical-support-chat-v1"
    assert "do not diagnose" in CHAT_PROMPT_V1.lower()


def test_chat_service_requires_configuration():
    service = MedicalChatService()
    service.api_key = ""
    service.model_name = ""
    with pytest.raises(RuntimeError):
        service.ask("What should I do about chest tightness?")
