from __future__ import annotations

from datetime import datetime, timezone
from types import SimpleNamespace

import pytest

from app.services.ai_inference import (
    BP_TARGET_SAMPLING_RATE,
    ECG_RECORD_INPUT_SAMPLES,
    InferenceService,
    _meta_vector,
    _morphology_beat_windows,
    _sequence_tensor,
)
from app.services.ai_prompts import CHAT_PROMPT_VERSION, CHAT_PROMPT_V1
from app.services.chat_service import MedicalChatService


def _reading(timestamp: datetime, ecg: list[float], ppg: list[float]) -> SimpleNamespace:
    return SimpleNamespace(
        timestamp=timestamp,
        sampling_rate=250,
        ecg=ecg,
        ppg=ppg,
    )


def _patient(weight: str = "70", height: str = "175") -> SimpleNamespace:
    return SimpleNamespace(weight=weight, height=height)


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
    service.morphology_adapter.predict = lambda ecg, sampling_rate=250: {
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

    ecg = [0.0] * ECG_RECORD_INPUT_SAMPLES
    ppg = [1.0] * ECG_RECORD_INPUT_SAMPLES
    for index in range(40, ECG_RECORD_INPUT_SAMPLES, 250):
        ecg[index] = 1.5
        ppg[index] = 2.0

    result = service.analyze(
        [
            _reading(datetime.now(timezone.utc), ecg, ppg),
            _reading(datetime.now(timezone.utc), ecg, ppg),
        ],
        patient=_patient(),
    )

    assert result["metrics"]["ai_input"]["reading_count"] == 2
    assert result["metrics"]["ai_input"]["ecg_samples"] == ECG_RECORD_INPUT_SAMPLES * 2
    assert result["metrics"]["ai_input"]["ppg_samples"] == ECG_RECORD_INPUT_SAMPLES * 2
    assert result["metrics"]["ai_input"]["ecg_record_required_samples"] == ECG_RECORD_INPUT_SAMPLES
    models = result["predictions"]["models"]
    assert models["ecg_arrhythmia_v31"]["status"] == "completed"
    assert models["blood_pressure_vital_meta"]["systolic_mmHg"] == 120.0
    assert result["status"] == "completed"


def test_short_ecg_record_model_is_marked_unavailable(monkeypatch):
    service = InferenceService()
    service.ecg_adapter.predict = lambda ecg: {
        "model_available": False,
        "reason": f"Need at least {ECG_RECORD_INPUT_SAMPLES} ECG samples for record-level classification.",
        "sample_count": len(ecg),
        "required_sample_count": ECG_RECORD_INPUT_SAMPLES,
    }
    service.morphology_adapter.predict = lambda ecg, sampling_rate=250: {
        "model_available": False,
        "reason": "Could not extract a complete beat-centered ECG window for morphology classification.",
    }
    service.bp_adapter.predict = lambda ppg, sampling_rate, patient=None: {
        "model_available": False,
        "reason": "Blood pressure model requires assigned patient metadata: positive weight and height.",
    }

    result = service.analyze([
        _reading(datetime.now(timezone.utc), [0.0, 1.0, 0.0], [1.0, 2.0, 1.0])
    ])

    ecg_model = result["predictions"]["models"]["ecg_arrhythmia_v31"]
    assert result["status"] == "degraded"
    assert ecg_model["status"] == "unavailable"
    assert ecg_model["required_sample_count"] == ECG_RECORD_INPUT_SAMPLES


def test_flat_ppg_contact_reports_no_pulse_reason(monkeypatch):
    service = InferenceService()
    service.ecg_adapter.predict = lambda ecg: {"model_available": False, "reason": "stub"}
    service.morphology_adapter.predict = lambda ecg, sampling_rate=250: {
        "model_available": False,
        "reason": "stub",
    }
    service.bp_adapter.predict = lambda ppg, sampling_rate, patient=None: {
        "model_available": False,
        "reason": "Insufficient PPG data to build a five-beat sequence at the model sampling rate.",
    }

    reading = _reading(
        datetime.now(timezone.utc),
        [0.0] * ECG_RECORD_INPUT_SAMPLES,
        [54000.0] * ECG_RECORD_INPUT_SAMPLES,
    )
    reading.metadata_json = {
        "finger_detected": True,
        "ppg_sensor_ready": True,
        "ir_mean": 54000.0,
        "ir_ac_rms": 28.0,
        "spo2_percent": 83.8,
    }

    result = service.analyze([reading])

    metrics = result["metrics"]
    assert metrics["spo2_percent"] == 83.8
    assert metrics["perfusion_index_percent"] == pytest.approx(0.05, abs=0.01)
    assert metrics["ppg_rate_bpm"] is None
    assert metrics["ppg_peak_count"] == 0
    assert "not contain enough repeating pulse peaks" in metrics["ppg_rate_reason"]


def test_spo2_analysis_uses_recent_hardware_values(monkeypatch):
    service = InferenceService()
    service.ecg_adapter.predict = lambda ecg: {"model_available": False, "reason": "stub"}
    service.morphology_adapter.predict = lambda ecg, sampling_rate=250: {
        "model_available": False,
        "reason": "stub",
    }
    service.bp_adapter.predict = lambda ppg, sampling_rate, patient=None: {
        "model_available": False,
        "reason": "stub",
    }

    readings = []
    for index in range(12):
        reading = _reading(
            datetime(2026, 1, 1, 0, 0, index, tzinfo=timezone.utc),
            [0.0, 1.0, 0.0],
            [54000.0, 54100.0, 54000.0],
        )
        reading.metadata_json = {"spo2_percent": 80.0 if index < 2 else 96.0}
        readings.append(reading)

    result = service.analyze(readings)

    assert result["metrics"]["spo2_percent"] == 96.0
    assert result["metrics"]["spo2_sample_count"] == 10
    assert result["metrics"]["spo2_source"] == "recent_hardware_red_ir_estimate"


def test_morphology_windows_are_beat_centered():
    ecg = [0.0] * 700
    for index in (120, 320, 520):
        ecg[index] = 1.8

    windows = _morphology_beat_windows(ecg, sampling_rate=250)

    assert windows
    assert all(len(window) == 186 for window in windows)


def test_bp_sequence_tensor_resamples_to_model_rate():
    ppg = [0.0] * 2500
    for index in range(100, 2500, 250):
        ppg[index] = 500.0

    sequence = _sequence_tensor(ppg, sampling_rate=250)

    assert sequence is not None
    assert len(sequence) == 1
    assert len(sequence[0]) == 5
    assert len(sequence[0][0]) == 128
    assert len(sequence[0][0][0]) == 3
    assert BP_TARGET_SAMPLING_RATE == 125


def test_bp_meta_requires_patient_weight_and_height():
    assert _meta_vector(None) is None
    assert _meta_vector(_patient(weight="", height="175")) is None
    assert _meta_vector(_patient(weight="70", height="1.75")) == pytest.approx([70.0, 175.0, 22.85714])
    assert _meta_vector(_patient(weight="70 kg", height="175 cm")) == pytest.approx([70.0, 175.0, 22.85714])
    assert _meta_vector(_patient(weight="154 lbs", height="69 in")) == pytest.approx(
        [69.8532, 175.26, 22.747],
        rel=1e-3,
    )


def test_chat_prompt_version_is_named():
    assert CHAT_PROMPT_VERSION == "medical-support-chat-v1"
    assert "do not diagnose" in CHAT_PROMPT_V1.lower()


def test_chat_service_requires_configuration():
    service = MedicalChatService()
    service.api_key = ""
    service.model_name = ""
    with pytest.raises(RuntimeError):
        service.ask("What should I do about chest tightness?")
