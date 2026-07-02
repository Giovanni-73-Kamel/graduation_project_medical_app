from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Sequence


@dataclass(frozen=True)
class ReadingStorageResult:
    ecg: list[float]
    ppg: list[float]
    sample_count: int
    status: str
    metadata: dict[str, Any]


def signal_summary(values: Sequence[float]) -> dict:
    if not values:
        return {"count": 0}
    cleaned = [float(value) for value in values]
    minimum = min(cleaned)
    maximum = max(cleaned)
    return {
        "count": len(cleaned),
        "min": round(float(minimum), 6),
        "max": round(float(maximum), 6),
        "mean": round(float(sum(cleaned) / len(cleaned)), 6),
        "amplitude": round(float(maximum - minimum), 6),
        "first": round(float(cleaned[0]), 6),
        "last": round(float(cleaned[-1]), 6),
    }


def is_low_information_signal(values: Sequence[float]) -> bool:
    if not values:
        return True
    cleaned = [float(value) for value in values]
    return abs(max(cleaned) - min(cleaned)) < 1e-8


def safe_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        numeric = float(value)
    except (TypeError, ValueError):
        return None
    return numeric if numeric == numeric else None


def ppg_contact_from_signal(values: Sequence[float], metadata: dict[str, Any]) -> bool:
    cleaned = [float(value) for value in values]
    if len(cleaned) < 3 or metadata.get("ppg_sensor_ready") is False:
        return False
    mean = safe_float(metadata.get("ir_mean"))
    if mean is None:
        mean = sum(cleaned) / len(cleaned)
    amplitude = safe_float(metadata.get("ir_amplitude"))
    if amplitude is None:
        amplitude = max(cleaned) - min(cleaned)
    ac_rms = safe_float(metadata.get("ir_ac_rms"))
    threshold = safe_float(metadata.get("finger_ir_threshold")) or 50000.0
    relaxed_threshold = safe_float(metadata.get("finger_ir_relaxed_threshold")) or 12000.0
    ac_threshold = safe_float(metadata.get("finger_ir_ac_threshold")) or 80.0
    amplitude_threshold = safe_float(metadata.get("finger_ir_amplitude_threshold")) or 150.0
    allow_dc_only = metadata.get("finger_allow_dc_only") is True

    if allow_dc_only and mean >= threshold:
        return True
    if ac_rms is not None:
        return mean >= relaxed_threshold and ac_rms >= ac_threshold and amplitude >= amplitude_threshold
    return mean >= relaxed_threshold and amplitude >= amplitude_threshold


def cap_signal_samples(values: Sequence[float], max_samples: int) -> list[float]:
    cleaned = [float(value) for value in values]
    if max_samples <= 0 or len(cleaned) <= max_samples:
        return cleaned
    if max_samples == 1:
        return [cleaned[0]]
    step = (len(cleaned) - 1) / (max_samples - 1)
    return [float(cleaned[round(index * step)]) for index in range(max_samples)]


def prepare_reading_storage(
    *,
    ecg_values: Sequence[float],
    ppg_values: Sequence[float],
    status: str,
    metadata: dict[str, Any] | None,
    compact_invalid_signals: bool,
    max_raw_signal_samples: int,
) -> ReadingStorageResult:
    ecg = [float(value) for value in ecg_values]
    ppg = [float(value) for value in ppg_values]
    prepared_metadata: dict[str, Any] = dict(metadata or {})
    effective_status = status
    if status == "no_finger" and ppg_contact_from_signal(ppg, prepared_metadata):
        prepared_metadata["hardware_status"] = status
        prepared_metadata["hardware_finger_detected"] = prepared_metadata.get("finger_detected")
        prepared_metadata["finger_detected"] = True
        prepared_metadata["finger_detected_backend_override"] = True
        effective_status = "active"

    original_sample_count = min(len(ecg), len(ppg))
    storage = {
        "policy": "compact_invalid_channels_v1",
        "original_sample_count": original_sample_count,
        "original_ecg_samples": len(ecg),
        "original_ppg_samples": len(ppg),
        "dropped_signals": [],
        "capped_signals": [],
    }

    if compact_invalid_signals:
        ppg_sensor_ready = prepared_metadata.get("ppg_sensor_ready")
        finger_detected = prepared_metadata.get("finger_detected")
        if effective_status == "ppg_sensor_off" or ppg_sensor_ready is False:
            storage["dropped_signals"].append(
                {"signal": "ppg", "reason": "ppg_sensor_off", "summary": signal_summary(ppg)}
            )
            ppg = []
        elif effective_status == "no_finger" or finger_detected is False:
            storage["dropped_signals"].append(
                {"signal": "ppg", "reason": "finger_not_detected", "summary": signal_summary(ppg)}
            )
            ppg = []

        if effective_status == "leads_off" or is_low_information_signal(ecg):
            storage["dropped_signals"].append(
                {"signal": "ecg", "reason": "leads_off_or_flat_signal", "summary": signal_summary(ecg)}
            )
            ecg = []

        if ppg and is_low_information_signal(ppg):
            storage["dropped_signals"].append(
                {"signal": "ppg", "reason": "flat_signal", "summary": signal_summary(ppg)}
            )
            ppg = []

    max_samples = max(0, max_raw_signal_samples)
    if max_samples and len(ecg) > max_samples:
        storage["capped_signals"].append(
            {"signal": "ecg", "from": len(ecg), "to": max_samples, "summary": signal_summary(ecg)}
        )
        ecg = cap_signal_samples(ecg, max_samples)
    if max_samples and len(ppg) > max_samples:
        storage["capped_signals"].append(
            {"signal": "ppg", "from": len(ppg), "to": max_samples, "summary": signal_summary(ppg)}
        )
        ppg = cap_signal_samples(ppg, max_samples)

    storage["stored_ecg_samples"] = len(ecg)
    storage["stored_ppg_samples"] = len(ppg)
    prepared_metadata["storage"] = storage

    return ReadingStorageResult(
        ecg=ecg,
        ppg=ppg,
        sample_count=original_sample_count,
        status=effective_status,
        metadata=prepared_metadata,
    )
