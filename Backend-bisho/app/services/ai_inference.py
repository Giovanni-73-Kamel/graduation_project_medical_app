from __future__ import annotations

import importlib.util
import logging
import math
import re
import statistics
from dataclasses import dataclass
from pathlib import Path
from time import perf_counter
from typing import Any, Dict, Iterable, List, Sequence

import numpy as np

from app.config import settings
from app.services.signal_processing import analyze_signals, detect_peaks, detrend, flatten_signal

DISCLAIMER = "Decision-support only, not a final medical diagnosis."
logger = logging.getLogger(__name__)

ECG_RECORD_INPUT_SAMPLES = 1250
MORPHOLOGY_INPUT_SAMPLES = 186
MORPHOLOGY_PRE_PEAK_SAMPLES = 70
MORPHOLOGY_MAX_BEATS = 8
BP_TARGET_SAMPLING_RATE = 125
BP_INPUT_SAMPLES_PER_BEAT = 128
BP_SEQUENCE_LENGTH = 5
BP_PRE_PEAK_SAMPLES = 30
BP_POST_PEAK_SAMPLES = BP_INPUT_SAMPLES_PER_BEAT - BP_PRE_PEAK_SAMPLES
ANALYSIS_WINDOW_SECONDS = 30


@dataclass(frozen=True)
class ModelMetadata:
    name: str
    provider: str
    purpose: str
    input_format: str
    output_format: str
    model_version: str
    timeout_seconds: int
    retry_attempts: int
    fallback: str


def _resolve_model_dir(model_dir: str) -> Path:
    configured = Path(model_dir)
    if configured.is_absolute():
        return configured

    backend_root = Path(__file__).resolve().parents[2]
    repo_root = backend_root.parent
    candidates = [
        (backend_root / configured).resolve(),
        (repo_root / configured).resolve(),
        configured.resolve(),
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return candidates[0]


def _load_module(module_path: Path, module_name: str) -> Any:
    spec = importlib.util.spec_from_file_location(module_name, module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load module spec for {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _safe_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        numeric = float(value)
    except (TypeError, ValueError):
        return None
    if not math.isfinite(numeric):
        return None
    return numeric


def _patient_measurement(value: Any, measurement_type: str) -> float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        numeric = _safe_float(value)
        if numeric is None or numeric <= 0:
            return None
        if measurement_type == "height" and numeric <= 10:
            return numeric * 100.0
        return numeric

    text = str(value).strip().lower()
    if not text:
        return None
    match = re.search(r"-?\d+(?:\.\d+)?", text)
    if match is None:
        return None
    numeric = _safe_float(match.group(0))
    if numeric is None or numeric <= 0:
        return None

    if measurement_type == "weight":
        if any(unit in text for unit in ("lb", "lbs", "pound")):
            return numeric * 0.45359237
        return numeric

    if any(unit in text for unit in (" inch", " inches", " in", "inches")):
        return numeric * 2.54
    if re.search(r"\bm\b", text) and "cm" not in text:
        return numeric * 100.0
    return numeric if numeric > 10 else numeric * 100.0


def _resample(values: Sequence[float], target_length: int) -> List[float]:
    if target_length <= 0:
        return []
    cleaned = [float(value) for value in values]
    if not cleaned:
        return [0.0 for _ in range(target_length)]
    if len(cleaned) == target_length:
        return cleaned
    if len(cleaned) == 1:
        return [cleaned[0] for _ in range(target_length)]

    scale = (len(cleaned) - 1) / max(target_length - 1, 1)
    resampled: List[float] = []
    for index in range(target_length):
        position = index * scale
        left_index = int(math.floor(position))
        right_index = min(left_index + 1, len(cleaned) - 1)
        fraction = position - left_index
        left_value = cleaned[left_index]
        right_value = cleaned[right_index]
        resampled.append(left_value + (right_value - left_value) * fraction)
    return resampled


def _resample_sampling_rate(values: Sequence[float], source_rate: int, target_rate: int) -> List[float]:
    if source_rate <= 0 or target_rate <= 0 or source_rate == target_rate:
        return [float(value) for value in values]
    target_length = max(1, int(round(len(values) * target_rate / source_rate)))
    return _resample(values, target_length)


def _centered_beats(signal: Sequence[float], peaks: Sequence[int], pre_peak: int, post_peak: int) -> List[List[float]]:
    beats: List[List[float]] = []
    for peak in peaks:
        start = peak - pre_peak
        end = peak + post_peak
        if start < 0 or end > len(signal):
            continue
        beat = [float(value) for value in signal[start:end]]
        if len(beat) == pre_peak + post_peak:
            beats.append(beat)
    return beats


def _beat_features(beat: Sequence[float]) -> List[List[float]]:
    if not beat:
        return []
    mean = statistics.fmean(beat)
    std = statistics.pstdev(beat) if len(beat) > 1 else 0.0
    normalized = [0.0 if std < 1e-8 else (value - mean) / std for value in beat]
    first_derivative = [0.0]
    for index in range(1, len(normalized)):
        first_derivative.append(normalized[index] - normalized[index - 1])
    second_derivative = [0.0]
    for index in range(1, len(first_derivative)):
        second_derivative.append(first_derivative[index] - first_derivative[index - 1])
    return [
        [
            float(normalized[index]),
            float(first_derivative[index]),
            float(second_derivative[index]),
        ]
        for index in range(len(normalized))
    ]


def _morphology_beat_windows(ecg_signal: Sequence[float], sampling_rate: int) -> List[List[float]]:
    if len(ecg_signal) < MORPHOLOGY_INPUT_SAMPLES:
        return []
    filtered_signal = detrend(ecg_signal, sampling_rate)
    peaks = detect_peaks(filtered_signal, sampling_rate)
    beats = _centered_beats(
        ecg_signal,
        peaks,
        pre_peak=MORPHOLOGY_PRE_PEAK_SAMPLES,
        post_peak=MORPHOLOGY_INPUT_SAMPLES - MORPHOLOGY_PRE_PEAK_SAMPLES,
    )
    return beats[-MORPHOLOGY_MAX_BEATS:]


def _aggregate_class_predictions(predictions: Sequence[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
    if not predictions:
        return {}

    class_names = sorted({name for classes in predictions for name in classes})
    aggregated: Dict[str, Dict[str, Any]] = {}
    for class_name in class_names:
        class_predictions = [classes[class_name] for classes in predictions if class_name in classes]
        probabilities = [
            probability
            for probability in (_safe_float(values.get("probability")) for values in class_predictions)
            if probability is not None
        ]
        confidences = [
            confidence
            for confidence in (_safe_float(values.get("confidence")) for values in class_predictions)
            if confidence is not None
        ]
        thresholds = [
            threshold
            for threshold in (_safe_float(values.get("threshold")) for values in class_predictions)
            if threshold is not None
        ]
        detected_count = sum(1 for values in class_predictions if values.get("detected") is True)
        probability = statistics.fmean(probabilities) if probabilities else 0.0
        confidence = statistics.fmean(confidences) if confidences else 0.0
        threshold = thresholds[0] if thresholds else None
        aggregated[class_name] = {
            "detected": bool(probability >= threshold) if threshold is not None else detected_count >= max(1, len(class_predictions) / 2),
            "probability": round(probability, 4),
            "confidence": round(confidence, 4),
        }
        if threshold is not None:
            aggregated[class_name]["threshold"] = threshold
    return aggregated


def _sequence_tensor(ppg_signal: Sequence[float], sampling_rate: int) -> List[List[List[List[float]]]] | None:
    if len(ppg_signal) < BP_INPUT_SAMPLES_PER_BEAT:
        return None
    model_rate_signal = _resample_sampling_rate(ppg_signal, sampling_rate, BP_TARGET_SAMPLING_RATE)
    filtered_signal = detrend(model_rate_signal, BP_TARGET_SAMPLING_RATE)
    peaks = detect_peaks(filtered_signal, BP_TARGET_SAMPLING_RATE)
    beats = _centered_beats(
        filtered_signal,
        peaks,
        pre_peak=BP_PRE_PEAK_SAMPLES,
        post_peak=BP_POST_PEAK_SAMPLES,
    )
    if len(beats) < BP_SEQUENCE_LENGTH:
        return None
    sequence_beats = beats[-BP_SEQUENCE_LENGTH:]
    return [[_beat_features(beat) for beat in sequence_beats]]


def _meta_vector(patient: Any | None) -> List[float] | None:
    if patient is None:
        return None

    weight = _patient_measurement(getattr(patient, "weight", None), "weight")
    height = _patient_measurement(getattr(patient, "height", None), "height")
    if weight is None or weight <= 0 or height is None or height <= 0:
        return None

    height_cm = height if height > 10 else height * 100.0
    height_m = height_cm / 100.0
    bmi = weight / (height_m * height_m)

    return [
        weight,
        height_cm,
        bmi,
    ]


class BaseModelAdapter:
    metadata: ModelMetadata

    def __init__(self, model_dir: str) -> None:
        self.model_dir = _resolve_model_dir(model_dir)
        self.model: Any = None
        self.load_error: str | None = None

    def _load_tensorflow(self) -> Any | None:
        try:
            import tensorflow as tf  # type: ignore

            return tf
        except Exception as exc:  # pragma: no cover - optional dependency
            self.load_error = str(exc)
            return None

    def status(self) -> Dict[str, Any]:
        return {
            "status": "loaded" if self.model is not None else ("unavailable" if self.load_error else "not_loaded"),
            "reason": self.load_error,
        }


class ECGInferenceAdapter(BaseModelAdapter):
    metadata = ModelMetadata(
        name="ecg_arrhythmia_v31",
        provider="local_keras",
        purpose="Record-level ECG arrhythmia classification",
        input_format="At least 1250 ECG samples; model input tensor is (batch, 1250, 1)",
        output_format="Per-class probability and confidence map",
        model_version="3.1",
        timeout_seconds=settings.ai_model_timeout_seconds,
        retry_attempts=settings.ai_model_retry_attempts,
        fallback="signal_quality_only",
    )

    def __init__(self, model_dir: str, enabled: bool = True) -> None:
        super().__init__(model_dir)
        self.enabled = enabled
        self.classifier: Any = None

    def _load(self) -> None:
        if self.classifier is not None or self.load_error is not None or not self.enabled:
            return
        module_path = self.model_dir / "ecg_classifier_v31.py"
        if not module_path.exists():
            self.load_error = f"ECG model module not found at {module_path}"
            logger.warning(self.load_error)
            return
        try:
            module = _load_module(module_path, "ecg_classifier_v31")
            self.classifier = module.ECGClassifier(str(self.model_dir))
            self.model = self.classifier
        except Exception as exc:  # TensorFlow is optional in lightweight dev/test runs.
            self.load_error = str(exc)
            logger.warning("ECG model unavailable: %s", exc)

    def predict(self, ecg_signal: Sequence[float]) -> Dict[str, Any]:
        sample_count = len(ecg_signal)
        if sample_count < ECG_RECORD_INPUT_SAMPLES:
            return {
                "model_available": False,
                "reason": f"Need at least {ECG_RECORD_INPUT_SAMPLES} ECG samples for record-level classification.",
                "sample_count": sample_count,
                "required_sample_count": ECG_RECORD_INPUT_SAMPLES,
            }
        model_input = list(ecg_signal[-ECG_RECORD_INPUT_SAMPLES:])
        self._load()
        if self.classifier is None:
            return {
                "model_available": False,
                "reason": self.load_error or "ECG model loading is disabled.",
            }
        try:
            return {
                "model_available": True,
                "classes": self.classifier.predict(model_input),
                "sample_count": sample_count,
                "input_sample_count": len(model_input),
                "model_input_shape": [1, ECG_RECORD_INPUT_SAMPLES, 1],
            }
        except Exception as exc:
            logger.exception("ECG model prediction failed")
            return {
                "model_available": False,
                "reason": str(exc),
            }


class MorphologyInferenceAdapter(BaseModelAdapter):
    metadata = ModelMetadata(
        name="morphology_heartbeat_v1",
        provider="local_keras",
        purpose="Beat-level ECG morphology classification",
        input_format="Beat-centered ECG windows; model input tensor is (batch, 186, 1)",
        output_format="Per-class probability and confidence map",
        model_version="1.0_confidence",
        timeout_seconds=settings.ai_model_timeout_seconds,
        retry_attempts=settings.ai_model_retry_attempts,
        fallback="ecg_arrhythmia_v31",
    )

    def __init__(self, model_dir: str) -> None:
        super().__init__(model_dir)
        self.classifier: Any = None

    def _load(self) -> None:
        if self.classifier is not None or self.load_error is not None:
            return
        module_path = self.model_dir / "ecg_classifier.py"
        if not module_path.exists():
            self.load_error = f"Morphology model module not found at {module_path}"
            logger.warning(self.load_error)
            return
        try:
            module = _load_module(module_path, "morphology_ecg_classifier")
            self.classifier = module.ECGClassifier(str(self.model_dir))
            self.model = self.classifier
        except Exception as exc:
            self.load_error = str(exc)
            logger.warning("Morphology model unavailable: %s", exc)

    def predict(self, ecg_signal: Sequence[float], sampling_rate: int = 250) -> Dict[str, Any]:
        beats = _morphology_beat_windows(ecg_signal, sampling_rate)
        if not beats:
            return {
                "model_available": False,
                "reason": "Could not extract a complete beat-centered ECG window for morphology classification.",
                "sample_count": len(ecg_signal),
                "required_window_samples": MORPHOLOGY_INPUT_SAMPLES,
            }
        self._load()
        if self.classifier is None:
            return {
                "model_available": False,
                "reason": self.load_error or "Morphology model loading is disabled.",
            }
        try:
            beat_predictions = [self.classifier.predict(beat) for beat in beats]
            return {
                "model_available": True,
                "classes": _aggregate_class_predictions(beat_predictions),
                "beat_count": len(beats),
                "model_input_shape": [len(beats), MORPHOLOGY_INPUT_SAMPLES, 1],
            }
        except Exception as exc:
            logger.exception("Morphology model prediction failed")
            return {
                "model_available": False,
                "reason": str(exc),
            }


class BloodPressureInferenceAdapter(BaseModelAdapter):
    metadata = ModelMetadata(
        name="bp_vital_meta",
        provider="local_keras",
        purpose="Blood-pressure estimation from PPG beat sequences and patient metadata",
        input_format="PPG tensor (batch, 5, 128, 3) at 125 Hz plus metadata tensor (batch, 3): Weight, Height, BMI",
        output_format="Estimated systolic and diastolic blood pressure",
        model_version="v1",
        timeout_seconds=settings.ai_model_timeout_seconds,
        retry_attempts=settings.ai_model_retry_attempts,
        fallback="signal_metrics_only",
    )

    def __init__(self, model_dir: str) -> None:
        super().__init__(model_dir)
        self.scaler_y: Any = None
        self.meta_scaler: Any = None

    def _load_artifact(self, filename: str) -> Any | None:
        path = self.model_dir / filename
        if not path.exists():
            return None
        try:
            import pickle

            with open(path, "rb") as file:
                try:
                    return pickle.load(file)
                except pickle.UnpicklingError:
                    import joblib

                    file.seek(0)
                    return joblib.load(file)
        except Exception as exc:
            logger.warning("Could not load BP artifact %s: %s", path, exc)
            return None

    def _load(self) -> None:
        if self.model is not None or self.load_error is not None:
            return
        model_path = self.model_dir / "bp_model.keras"
        if not model_path.exists():
            self.load_error = f"Blood pressure model not found at {model_path}"
            logger.warning(self.load_error)
            return
        tf = self._load_tensorflow()
        if tf is None:
            return
        try:
            self.model = tf.keras.models.load_model(str(model_path), compile=False)
            self.scaler_y = self._load_artifact("scaler_y.pkl")
            self.meta_scaler = self._load_artifact("meta_scaler.pkl")
        except Exception as exc:
            self.load_error = str(exc)
            logger.warning("Blood pressure model unavailable: %s", exc)

    def predict(
        self,
        ppg_signal: Sequence[float],
        sampling_rate: int,
        patient: Any | None = None,
    ) -> Dict[str, Any]:
        meta_vector = _meta_vector(patient)
        if meta_vector is None:
            return {
                "model_available": False,
                "reason": "Blood pressure model requires assigned patient metadata: positive weight and height.",
            }

        self._load()
        if self.model is None:
            return {
                "model_available": False,
                "reason": self.load_error or "Blood pressure model loading is disabled.",
            }

        sequence = _sequence_tensor(ppg_signal, sampling_rate)
        if sequence is None:
            return {
                "model_available": False,
                "reason": "Insufficient PPG data to build a five-beat sequence at the model sampling rate.",
                "source_sampling_rate": sampling_rate,
                "model_sampling_rate": BP_TARGET_SAMPLING_RATE,
            }

        sequence_array = np.asarray(sequence, dtype=np.float32)
        meta_array = np.asarray([meta_vector], dtype=np.float32)
        if self.meta_scaler is not None:
            meta_array = self.meta_scaler.transform(meta_array).astype(np.float32)
        try:
            prediction = self.model.predict(
                {"sequence_input": sequence_array, "meta_input": meta_array},
                verbose=0,
            )
        except Exception:
            try:
                prediction = self.model.predict([sequence_array, meta_array], verbose=0)
            except Exception as exc:
                logger.exception("Blood pressure model prediction failed")
                return {
                    "model_available": False,
                    "reason": str(exc),
                }

        systolic = None
        diastolic = None
        confidence = None
        if isinstance(prediction, (list, tuple)):
            if len(prediction) >= 2:
                first_flat = np.asarray(prediction[0]).reshape(-1)
                second_flat = np.asarray(prediction[1]).reshape(-1)
                if first_flat.size and second_flat.size:
                    bp_values = np.asarray([[float(first_flat[0]), float(second_flat[0])]], dtype=np.float32)
                    if self.scaler_y is not None:
                        bp_values = self.scaler_y.inverse_transform(bp_values)
                    systolic = _safe_float(bp_values[0][0])
                    diastolic = _safe_float(bp_values[0][1])
            elif prediction:
                first = np.asarray(prediction[0]).reshape(-1)
                if first.size >= 2:
                    bp_values = np.asarray([[float(first[0]), float(first[1])]], dtype=np.float32)
                    if self.scaler_y is not None:
                        bp_values = self.scaler_y.inverse_transform(bp_values)
                    systolic = _safe_float(bp_values[0][0])
                    diastolic = _safe_float(bp_values[0][1])
            if len(prediction) > 2:
                confidence_values = np.asarray(prediction[2]).reshape(-1)
                confidence = _safe_float(confidence_values[0]) if confidence_values.size else None
        else:
            try:
                first_item = prediction[0]
            except Exception:
                flat = [prediction]
            else:
                if hasattr(first_item, "__iter__") and not isinstance(first_item, (str, bytes)):
                    flat = list(first_item)
                else:
                    flat = [first_item]
            if len(flat) >= 2:
                systolic = _safe_float(flat[0])
                diastolic = _safe_float(flat[1])

        return {
            "model_available": True,
            "systolic_mmHg": round(systolic, 1) if systolic is not None else None,
            "diastolic_mmHg": round(diastolic, 1) if diastolic is not None else None,
            "confidence": round(confidence, 4) if confidence is not None else None,
            "meta_vector": {
                "weight": meta_vector[0],
                "height": meta_vector[1],
                "bmi": meta_vector[2],
            },
            "model_input_shape": {
                "sequence_input": list(sequence_array.shape),
                "meta_input": list(meta_array.shape),
            },
            "source_sampling_rate": sampling_rate,
            "model_sampling_rate": BP_TARGET_SAMPLING_RATE,
        }


def _reading_metadata_values(readings: Sequence[Any], *keys: str) -> List[float]:
    values: List[float] = []
    for reading in readings:
        metadata = getattr(reading, "metadata_json", None) or {}
        if not isinstance(metadata, dict):
            continue
        for key in keys:
            value = _safe_float(metadata.get(key))
            if value is not None:
                values.append(value)
                break
    return values


def _recent_reading_metadata_values(
    readings: Sequence[Any],
    *keys: str,
    limit: int = 10,
) -> List[float]:
    values: List[float] = []
    for reading in reversed(list(readings)):
        metadata = getattr(reading, "metadata_json", None) or {}
        if not isinstance(metadata, dict):
            continue
        for key in keys:
            value = _safe_float(metadata.get(key))
            if value is not None:
                values.append(value)
                break
        if len(values) >= limit:
            break
    return list(reversed(values))


def _metadata_perfusion_index(readings: Sequence[Any]) -> float | None:
    ratios: List[float] = []
    for reading in readings:
        metadata = getattr(reading, "metadata_json", None) or {}
        if not isinstance(metadata, dict):
            continue
        ac_rms = _safe_float(metadata.get("ir_ac_rms"))
        mean = _safe_float(metadata.get("ir_mean"))
        if ac_rms is not None and mean is not None and mean > 1e-8:
            ratios.append(abs(ac_rms / mean) * 100.0)
    if not ratios:
        return None
    return round(statistics.fmean(ratios), 2)


class InferenceService:
    def __init__(self) -> None:
        self.ecg_adapter = ECGInferenceAdapter(
            settings.ecg_model_dir,
            enabled=settings.ecg_model_enabled,
        )
        self.morphology_adapter = MorphologyInferenceAdapter(settings.morphology_model_dir)
        self.bp_adapter = BloodPressureInferenceAdapter(settings.bp_model_dir)

    def model_metadata(self) -> List[Dict[str, Any]]:
        return [
            {**self.ecg_adapter.metadata.__dict__, **self.ecg_adapter.status()},
            {**self.morphology_adapter.metadata.__dict__, **self.morphology_adapter.status()},
            {**self.bp_adapter.metadata.__dict__, **self.bp_adapter.status()},
        ]

    def analyze(self, readings: Sequence[Any], patient: Any | None = None) -> Dict[str, Any]:
        if not readings:
            raise ValueError("Cannot analyze a session without readings")

        sorted_readings = sorted(readings, key=lambda reading: reading.timestamp)
        sampling_rate = int(sorted_readings[0].sampling_rate or 250)
        total_ecg = flatten_signal(reading.ecg for reading in sorted_readings)
        total_ppg = flatten_signal(reading.ppg for reading in sorted_readings)
        analysis_samples = max(
            sampling_rate * ANALYSIS_WINDOW_SECONDS,
            ECG_RECORD_INPUT_SAMPLES,
            BP_INPUT_SAMPLES_PER_BEAT * BP_SEQUENCE_LENGTH * 4,
        )
        ecg = total_ecg[-analysis_samples:]
        ppg = total_ppg[-analysis_samples:]

        signal_result = analyze_signals(ecg, ppg, sampling_rate)
        signal_result["metrics"]["ai_input"] = {
            "reading_count": len(sorted_readings),
            "sampling_rate_hz": sampling_rate,
            "ecg_samples": len(total_ecg),
            "ppg_samples": len(total_ppg),
            "analysis_window_seconds": ANALYSIS_WINDOW_SECONDS,
            "analyzed_ecg_samples": len(ecg),
            "analyzed_ppg_samples": len(ppg),
            "ecg_record_required_samples": ECG_RECORD_INPUT_SAMPLES,
            "morphology_window_required_samples": MORPHOLOGY_INPUT_SAMPLES,
            "bp_required_sequence_beats": BP_SEQUENCE_LENGTH,
            "bp_required_samples_per_beat": BP_INPUT_SAMPLES_PER_BEAT,
            "bp_model_sampling_rate_hz": BP_TARGET_SAMPLING_RATE,
        }
        spo2_values = _recent_reading_metadata_values(
            sorted_readings,
            "spo2_percent",
            "estimated_spo2_percent",
            "spO2",
            "spo2",
            limit=10,
        )
        if spo2_values:
            signal_result["metrics"]["spo2_percent"] = round(statistics.fmean(spo2_values), 1)
            signal_result["metrics"]["spo2_source"] = "recent_hardware_red_ir_estimate"
            signal_result["metrics"]["spo2_sample_count"] = len(spo2_values)
        else:
            signal_result["metrics"]["spo2_percent"] = None
            signal_result["metrics"]["spo2_source"] = "unavailable"
        metadata_perfusion = _metadata_perfusion_index(sorted_readings)
        if metadata_perfusion is not None:
            signal_result["metrics"]["perfusion_index_percent"] = metadata_perfusion
            signal_result["metrics"]["perfusion_index_source"] = "hardware_ir_ac_rms"
        else:
            signal_result["metrics"]["perfusion_index_source"] = "session_ppg_amplitude"
        ppg_peak_count = len(signal_result.get("peaks", {}).get("ppg", []))
        signal_result["metrics"]["ppg_peak_count"] = ppg_peak_count
        if signal_result["metrics"].get("ppg_rate_bpm") is None:
            signal_result["metrics"]["ppg_rate_reason"] = (
                "PPG contact is detected, but the waveform does not contain enough repeating pulse peaks."
                if ppg
                else "No usable PPG samples were stored."
            )

        ecg_prediction = self._predict_with_timeout(
            self.ecg_adapter.predict,
            settings.ai_model_timeout_seconds,
            ecg,
        )
        morphology_prediction = self._predict_with_timeout(
            self.morphology_adapter.predict,
            settings.ai_model_timeout_seconds,
            ecg,
            sampling_rate,
        )
        bp_prediction = self._predict_with_timeout(
            self.bp_adapter.predict,
            settings.ai_model_timeout_seconds,
            ppg,
            sampling_rate,
            patient,
        )

        predictions = {
            "ecg_arrhythmia_v31": self._normalized_ecg_prediction(ecg_prediction),
            "morphology_heartbeat_v1": self._normalized_ecg_prediction(morphology_prediction),
            "blood_pressure_vital_meta": self._normalized_bp_prediction(bp_prediction),
        }
        summary = self._summary(signal_result["metrics"], predictions)
        alerts = list(signal_result["alerts"])
        alerts.extend(self._alerts_from_predictions(predictions))

        status = "completed" if all(item.get("status") == "completed" for item in predictions.values()) else "degraded"
        return {
            "model_name": "ecg_ppg_multi_model_pipeline",
            "model_version": "2026.06.30",
            "status": status,
            "metrics": signal_result["metrics"],
            "signal_quality": signal_result["signal_quality"],
            "predictions": {
                "models": predictions,
                "summary": summary,
            },
            "alerts": alerts,
            "disclaimer": DISCLAIMER,
        }

    def metadata(self) -> List[Dict[str, Any]]:
        return self.model_metadata()

    def _predict_with_timeout(self, func: Any, timeout_seconds: int, *args: Any) -> Dict[str, Any]:
        attempts = max(1, settings.ai_model_retry_attempts + 1)
        last_error: str | None = None
        for attempt in range(attempts):
            started = perf_counter()
            try:
                result = func(*args)
                elapsed = perf_counter() - started
                if elapsed > timeout_seconds:
                    logger.warning(
                        "AI model call exceeded configured timeout: %.2fs > %ss",
                        elapsed,
                        timeout_seconds,
                    )
                if isinstance(result, dict):
                    result.setdefault("status", "completed" if result.get("model_available") else "unavailable")
                else:
                    result = {"status": "completed", "result": result}
                return result
            except Exception as exc:
                last_error = str(exc)
                logger.exception("AI model call failed on attempt %s/%s", attempt + 1, attempts)
        return {"status": "unavailable", "model_available": False, "reason": last_error}

    def _normalized_ecg_prediction(self, prediction: Dict[str, Any]) -> Dict[str, Any]:
        if not prediction.get("model_available"):
            return {
                "status": "unavailable",
                "model_available": False,
                "reason": prediction.get("reason", "Model unavailable"),
                **{
                    key: prediction[key]
                    for key in (
                        "sample_count",
                        "required_sample_count",
                        "required_window_samples",
                    )
                    if key in prediction
                },
            }
        classes = prediction.get("classes") or {}
        top_class = None
        if classes:
            scored = []
            for code, values in classes.items():
                probability = _safe_float(values.get("probability")) or 0.0
                confidence = _safe_float(values.get("confidence")) or 0.0
                scored.append((probability, confidence, code, values))
            probability, confidence, code, values = max(scored, key=lambda item: (item[0], item[1]))
            top_class = {
                "code": code,
                "probability": probability,
                "confidence": confidence,
                "threshold": values.get("threshold"),
                "detected": values.get("detected"),
            }
        normalized = {
            "status": "completed",
            "model_available": True,
            "classes": classes,
            "top_class": top_class,
        }
        for key in ("sample_count", "input_sample_count", "beat_count", "model_input_shape"):
            if key in prediction:
                normalized[key] = prediction[key]
        return normalized

    def _normalized_bp_prediction(self, prediction: Dict[str, Any]) -> Dict[str, Any]:
        if not prediction.get("model_available"):
            return {
                "status": "unavailable",
                "model_available": False,
                "reason": prediction.get("reason", "Model unavailable"),
                **{
                    key: prediction[key]
                    for key in (
                        "source_sampling_rate",
                        "model_sampling_rate",
                    )
                    if key in prediction
                },
            }
        return {
            "status": "completed",
            "model_available": True,
            "systolic_mmHg": prediction.get("systolic_mmHg"),
            "diastolic_mmHg": prediction.get("diastolic_mmHg"),
            "confidence": prediction.get("confidence"),
            "meta_vector": prediction.get("meta_vector", {}),
            "model_input_shape": prediction.get("model_input_shape", {}),
            "source_sampling_rate": prediction.get("source_sampling_rate"),
            "model_sampling_rate": prediction.get("model_sampling_rate"),
        }

    def _summary(self, metrics: Dict[str, Any], predictions: Dict[str, Any]) -> Dict[str, Any]:
        arrhythmia = predictions["ecg_arrhythmia_v31"]
        morphology = predictions["morphology_heartbeat_v1"]
        bp = predictions["blood_pressure_vital_meta"]
        summary: Dict[str, Any] = {
            "arrhythmia_risk": "unknown",
            "heart_rate_bpm": metrics.get("heart_rate_bpm"),
        }
        if arrhythmia.get("top_class"):
            top_class = arrhythmia["top_class"]
            confidence = _safe_float(top_class.get("confidence")) or 0.0
            if top_class.get("code") == "NORM":
                summary["arrhythmia_risk"] = "low"
            elif confidence >= 0.75:
                summary["arrhythmia_risk"] = "high"
            else:
                summary["arrhythmia_risk"] = "moderate"
        summary["morphology_status"] = morphology.get("status")
        summary["blood_pressure_status"] = bp.get("status")
        return summary

    def _alerts_from_predictions(self, predictions: Dict[str, Any]) -> List[Dict[str, str]]:
        alerts: List[Dict[str, str]] = []
        risk = predictions.get("ecg_arrhythmia_v31", {})
        if risk.get("top_class") and risk["top_class"].get("code") != "NORM":
            alerts.append(
                {
                    "severity": "warning",
                    "code": "arrhythmia_model_flag",
                    "message": "The ECG classifier flagged possible abnormal patterns.",
                }
            )
        bp = predictions.get("blood_pressure_vital_meta", {})
        if bp.get("systolic_mmHg") is not None and bp["systolic_mmHg"] > 180:
            alerts.append(
                {
                    "severity": "warning",
                    "code": "hypertensive_range",
                    "message": "The blood pressure model predicted a hypertensive-range systolic value.",
                }
            )
        return alerts


_service: InferenceService | None = None


def get_inference_service() -> InferenceService:
    global _service
    if _service is None:
        _service = InferenceService()
    return _service
