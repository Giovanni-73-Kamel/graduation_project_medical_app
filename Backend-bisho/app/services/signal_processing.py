from __future__ import annotations

import math
import statistics
from typing import Any, Dict, Iterable, List, Sequence


def flatten_signal(chunks: Iterable[Sequence[float]]) -> List[float]:
    values: List[float] = []
    for chunk in chunks:
        values.extend(float(value) for value in chunk)
    return values


def normalize_signal(values: Sequence[float]) -> List[float]:
    if not values:
        return []
    mean = statistics.fmean(values)
    variance = statistics.fmean((value - mean) ** 2 for value in values)
    std = math.sqrt(variance)
    if std < 1e-8:
        return [0.0 for _ in values]
    return [(value - mean) / std for value in values]


def moving_average(values: Sequence[float], window: int) -> List[float]:
    if window <= 1 or len(values) <= 2:
        return [float(value) for value in values]
    window = min(window, len(values))
    averaged: List[float] = []
    running_sum = 0.0
    queue: List[float] = []
    for value in values:
        running_sum += float(value)
        queue.append(float(value))
        if len(queue) > window:
            running_sum -= queue.pop(0)
        averaged.append(running_sum / len(queue))
    return averaged


def detrend(values: Sequence[float], sampling_rate: int) -> List[float]:
    if not values:
        return []
    baseline = moving_average(values, max(3, sampling_rate // 2))
    return [float(value) - baseline[index] for index, value in enumerate(values)]


def detect_peaks(values: Sequence[float], sampling_rate: int) -> List[int]:
    if len(values) < 3:
        return []
    normalized = normalize_signal(values)
    min_distance = max(1, int(0.3 * sampling_rate))
    threshold = 0.55
    peaks: List[int] = []
    last_peak = -min_distance
    for index in range(1, len(normalized) - 1):
        center = normalized[index]
        if center < threshold:
            continue
        if center <= normalized[index - 1] or center < normalized[index + 1]:
            continue
        if index - last_peak < min_distance:
            if peaks and center > normalized[peaks[-1]]:
                peaks[-1] = index
                last_peak = index
            continue
        peaks.append(index)
        last_peak = index
    return peaks


def calculate_rate_from_peaks(peaks: Sequence[int], sampling_rate: int) -> float | None:
    if len(peaks) < 2 or sampling_rate <= 0:
        return None
    intervals = [
        (peaks[index] - peaks[index - 1]) / sampling_rate
        for index in range(1, len(peaks))
        if peaks[index] > peaks[index - 1]
    ]
    valid = [interval for interval in intervals if 0.3 <= interval <= 2.5]
    if not valid:
        return None
    return round(60.0 / statistics.fmean(valid), 1)


def calculate_hrv(peaks: Sequence[int], sampling_rate: int) -> Dict[str, float | None]:
    if len(peaks) < 3 or sampling_rate <= 0:
        return {"rmssd_ms": None, "sdnn_ms": None}
    rr_ms = [
        1000.0 * (peaks[index] - peaks[index - 1]) / sampling_rate
        for index in range(1, len(peaks))
    ]
    rr_ms = [interval for interval in rr_ms if 300.0 <= interval <= 2500.0]
    if len(rr_ms) < 2:
        return {"rmssd_ms": None, "sdnn_ms": None}
    diffs = [rr_ms[index] - rr_ms[index - 1] for index in range(1, len(rr_ms))]
    rmssd = math.sqrt(statistics.fmean(diff * diff for diff in diffs)) if diffs else None
    sdnn = statistics.stdev(rr_ms) if len(rr_ms) > 1 else None
    return {
        "rmssd_ms": round(rmssd, 1) if rmssd is not None else None,
        "sdnn_ms": round(sdnn, 1) if sdnn is not None else None,
    }


def signal_quality(values: Sequence[float], peaks: Sequence[int], sampling_rate: int) -> Dict[str, Any]:
    if not values:
        return {"score": 0.0, "label": "missing", "reason": "No samples were received."}
    minimum = min(values)
    maximum = max(values)
    amplitude = maximum - minimum
    zero_ratio = sum(1 for value in values if abs(value) < 1e-8) / len(values)
    variance = statistics.fmean((value - statistics.fmean(values)) ** 2 for value in values)
    expected_peaks = max(1.0, len(values) / max(sampling_rate, 1) * 1.0)
    peak_score = min(1.0, len(peaks) / expected_peaks)
    amplitude_score = 1.0 if amplitude > 0.05 else max(0.0, amplitude / 0.05)
    noise_score = 1.0 if variance > 1e-6 else 0.2
    dropout_score = max(0.0, 1.0 - zero_ratio * 2.0)
    score = round(max(0.0, min(1.0, (peak_score + amplitude_score + noise_score + dropout_score) / 4.0)), 2)
    if score >= 0.75:
        label = "good"
    elif score >= 0.45:
        label = "fair"
    else:
        label = "poor"
    return {
        "score": score,
        "label": label,
        "sample_count": len(values),
        "peak_count": len(peaks),
        "amplitude": round(amplitude, 4),
        "dropout_ratio": round(zero_ratio, 3),
    }


def analyze_signals(ecg: Sequence[float], ppg: Sequence[float], sampling_rate: int) -> Dict[str, Any]:
    ecg_filtered = detrend(ecg, sampling_rate)
    ppg_filtered = detrend(ppg, sampling_rate)
    ecg_peaks = detect_peaks(ecg_filtered, sampling_rate)
    ppg_peaks = detect_peaks(ppg_filtered, sampling_rate)

    heart_rate = calculate_rate_from_peaks(ecg_peaks, sampling_rate)
    ppg_rate = calculate_rate_from_peaks(ppg_peaks, sampling_rate)
    hrv = calculate_hrv(ecg_peaks, sampling_rate)
    ecg_quality = signal_quality(ecg, ecg_peaks, sampling_rate)
    ppg_quality = signal_quality(ppg, ppg_peaks, sampling_rate)

    ppg_mean = statistics.fmean(ppg) if ppg else 0.0
    ppg_amplitude = (max(ppg) - min(ppg)) if ppg else 0.0
    perfusion_index = (
        round(abs(ppg_amplitude / ppg_mean) * 100.0, 2)
        if abs(ppg_mean) > 1e-8
        else None
    )

    alerts = build_alerts(heart_rate, hrv, ecg_quality, ppg_quality)
    return {
        "filtered": {
            "ecg": ecg_filtered,
            "ppg": ppg_filtered,
        },
        "peaks": {
            "ecg": ecg_peaks,
            "ppg": ppg_peaks,
        },
        "metrics": {
            "heart_rate_bpm": heart_rate,
            "ppg_rate_bpm": ppg_rate,
            "hrv_rmssd_ms": hrv["rmssd_ms"],
            "hrv_sdnn_ms": hrv["sdnn_ms"],
            "perfusion_index_percent": perfusion_index,
            "sample_count": min(len(ecg), len(ppg)),
            "duration_seconds": round(min(len(ecg), len(ppg)) / sampling_rate, 2)
            if sampling_rate > 0
            else None,
        },
        "signal_quality": {
            "ecg": ecg_quality,
            "ppg": ppg_quality,
        },
        "alerts": alerts,
    }


def build_alerts(
    heart_rate: float | None,
    hrv: Dict[str, float | None],
    ecg_quality: Dict[str, Any],
    ppg_quality: Dict[str, Any],
) -> List[Dict[str, str]]:
    alerts: List[Dict[str, str]] = []
    if heart_rate is not None and heart_rate > 120:
        alerts.append(
            {
                "severity": "warning",
                "code": "tachycardia_risk",
                "message": "Elevated heart rate detected in this recording.",
            }
        )
    if heart_rate is not None and heart_rate < 50:
        alerts.append(
            {
                "severity": "warning",
                "code": "bradycardia_risk",
                "message": "Low heart rate detected in this recording.",
            }
        )
    if hrv.get("rmssd_ms") is not None and hrv["rmssd_ms"] < 20:
        alerts.append(
            {
                "severity": "info",
                "code": "low_hrv",
                "message": "Low HRV may indicate stress, fatigue, or poor signal quality.",
            }
        )
    if ecg_quality.get("score", 0) < 0.45 or ppg_quality.get("score", 0) < 0.45:
        alerts.append(
            {
                "severity": "warning",
                "code": "low_signal_quality",
                "message": "Signal quality is low; check sensor contact before relying on this result.",
            }
        )
    return alerts
