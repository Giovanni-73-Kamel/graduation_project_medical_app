from __future__ import annotations

import importlib.util
import logging
import math
import statistics
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FutureTimeoutError
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Sequence

from app.config import settings
from app.services.signal_processing import analyze_signals, detect_peaks, flatten_signal

DISCLAIMER = "Decision-support only, not a final medical diagnosis."
logger = logging.getLogger(__name__)


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
        [float(value) for value in normalized],
        [float(value) for value in first_derivative],
        [float(value) for value in second_derivative],
    ]


def _sequence_tensor(ppg_signal: Sequence[float], sampling_rate: int) -> List[List[List[List[float]]]] | None:
    if len(ppg_signal) < 128:
        return None
    filtered_signal = [float(value) for value in ppg_signal]
    peaks = detect_peaks(filtered_signal, sampling_rate)
    beats = _centered_beats(filtered_signal, peaks, pre_peak=30, post_peak=98)
    if len(beats) < 5:
        return None
    sequence_beats = beats[-5:]
    return [[_beat_features(beat) for beat in sequence_beats]]


def _meta_vector(patient: Any | None) -> List[float]:
    if patient is None:
        return [0.0, 0.0, 0.0]

    weight = _safe_float(getattr(patient, "weight", None))
    height = _safe_float(getattr(patient, "height", None))
    bmi = None
    if weight is not None and height is not None and height > 0:
        height_m = height / 100.0 if height > 10 else height
        if height_m > 0:
            bmi = weight / (height_m * height_m)

    return [
        weight if weight is not None else 0.0,
        height if height is not None else 0.0,
        bmi if bmi is not None else 0.0,
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
        input_format="Flattened ECG waveform resampled to 1250 samples",
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
        self._load()
        if self.classifier is None:
            return {
                "model_available": False,
                "reason": self.load_error or "ECG model loading is disabled.",
            }
        try:
            return {
                "model_available": True,
                "classes": self.classifier.predict(ecg_signal),
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
        input_format="Flattened ECG waveform resampled to 186 samples",
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

    def predict(self, ecg_signal: Sequence[float]) -> Dict[str, Any]:
        self._load()
        if self.classifier is None:
            return {
                "model_available": False,
                "reason": self.load_error or "Morphology model loading is disabled.",
            }
        try:
            resampled = _resample(ecg_signal, 186)
            return {
                "model_available": True,
                "classes": self.classifier.predict(resampled),
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
        input_format="PPG beat tensor plus Weight, Height, BMI metadata",
        output_format="Estimated systolic and diastolic blood pressure",
        model_version="v1",
        timeout_seconds=settings.ai_model_timeout_seconds,
        retry_attempts=settings.ai_model_retry_attempts,
        fallback="signal_metrics_only",
    )

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
        except Exception as exc:
            self.load_error = str(exc)
            logger.warning("Blood pressure model unavailable: %s", exc)

    def predict(
        self,
        ppg_signal: Sequence[float],
        sampling_rate: int,
        patient: Any | None = None,
    ) -> Dict[str, Any]:
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
                "reason": "Insufficient PPG data to build a five-beat sequence.",
            }

        meta_vector = _meta_vector(patient)
        try:
            prediction = self.model.predict([sequence, [meta_vector]], verbose=0)
        except Exception:
            try:
                prediction = self.model.predict(sequence, verbose=0)
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
            first = prediction[0]
            if hasattr(first, "__len__") and len(first) >= 2:
                systolic = _safe_float(first[0])
                diastolic = _safe_float(first[1])
            if len(prediction) > 1 and hasattr(prediction[1], "__len__"):
                confidence = _safe_float(prediction[1][0]) if len(prediction[1]) else None
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
        }


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
        ecg = flatten_signal(reading.ecg for reading in sorted_readings)
        ppg = flatten_signal(reading.ppg for reading in sorted_readings)

        signal_result = analyze_signals(ecg, ppg, sampling_rate)

        ecg_prediction = self._predict_with_timeout(
            self.ecg_adapter.predict,
            settings.ai_model_timeout_seconds,
            ecg,
        )
        morphology_prediction = self._predict_with_timeout(
            self.morphology_adapter.predict,
            settings.ai_model_timeout_seconds,
            ecg,
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
            "model_version": "2026.05.27",
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
            with ThreadPoolExecutor(max_workers=1) as executor:
                future = executor.submit(func, *args)
                try:
                    result = future.result(timeout=timeout_seconds)
                    if isinstance(result, dict):
                        result.setdefault("status", "completed" if result.get("model_available") else "unavailable")
                    else:
                        result = {"status": "completed", "result": result}
                    return result
                except FutureTimeoutError:
                    last_error = f"Timed out after {timeout_seconds} seconds"
                    logger.warning("AI model call timed out on attempt %s/%s", attempt + 1, attempts)
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
        return {
            "status": "completed",
            "model_available": True,
            "classes": classes,
            "top_class": top_class,
        }

    def _normalized_bp_prediction(self, prediction: Dict[str, Any]) -> Dict[str, Any]:
        if not prediction.get("model_available"):
            return {
                "status": "unavailable",
                "model_available": False,
                "reason": prediction.get("reason", "Model unavailable"),
            }
        return {
            "status": "completed",
            "model_available": True,
            "systolic_mmHg": prediction.get("systolic_mmHg"),
            "diastolic_mmHg": prediction.get("diastolic_mmHg"),
            "confidence": prediction.get("confidence"),
            "meta_vector": prediction.get("meta_vector", {}),
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
