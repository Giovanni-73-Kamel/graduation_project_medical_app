from app.services.signal_processing import analyze_signals, detect_peaks, normalize_signal


def test_detect_peaks_finds_repeating_ecg_spikes():
    signal = [0.0] * 250
    for index in (40, 100, 160, 220):
        signal[index] = 2.0

    peaks = detect_peaks(signal, sampling_rate=250)

    assert len(peaks) == 4
    assert peaks[0] == 40


def test_analyze_signals_returns_metrics_and_quality():
    ecg = [0.0] * 300
    ppg = [0.0] * 300
    for index in (50, 125, 200, 275):
        ecg[index] = 1.5
        ppg[index] = 200.0

    result = analyze_signals(ecg, ppg, sampling_rate=250)

    assert result["metrics"]["sample_count"] == 300
    assert result["signal_quality"]["ecg"]["label"] in {"fair", "good"}
    assert "alerts" in result


def test_normalize_flat_signal_is_zeroed():
    assert normalize_signal([2.0, 2.0, 2.0]) == [0.0, 0.0, 0.0]
