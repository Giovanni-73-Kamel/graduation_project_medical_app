# ==========================================
# preprocessing.py
# Handles data loading, filtering, beat
# extraction, feature engineering, and
# sequence construction.
# ==========================================

import h5py
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from scipy.signal import find_peaks, butter, filtfilt
from google.colab import drive
import os

# ==========================================
# CONSTANTS
# ==========================================
FS         = 125    # Sampling rate (Hz)
TARGET_LEN = 128    # Samples per beat
PRE_PEAK   = 30     # Samples before systolic peak
POST_PEAK  = TARGET_LEN - PRE_PEAK   # 98 samples after peak
SEQ_LEN    = 5      # Consecutive beats per sequence

# ==========================================
# HELPER FUNCTIONS
# ==========================================

def calculate_bmi(weight_kg: float, height_cm: float) -> float:
    """
    Calculate Body Mass Index (BMI).
    
    Parameters
    ----------
    weight_kg : float
        Weight in kilograms.
    height_cm : float
        Height in centimeters.

    Returns
    -------
    float
        BMI value.
    """
    if height_cm <= 0 or weight_kg <= 0:
        return np.nan
    
    height_m = height_cm / 100.0
    return weight_kg / (height_m ** 2)

# ==========================================
# MOUNT GOOGLE DRIVE & LOAD DATA
# ==========================================

def load_data(file_path: str):
    """
    Mount Google Drive, load the HDF5 file, and return
    raw PPG windows, SBP/DBP labels, and BMI arrays.

    Returns
    -------
    ppg_raw : np.ndarray  shape (N, signal_len)
    sbp_raw : np.ndarray  shape (N,)
    dbp_raw : np.ndarray  shape (N,)
    bmi_raw : np.ndarray  shape (N,)
    """
    print("Mounting Google Drive...")
    drive.mount('/content/drive')

    if not os.path.exists(file_path):
        raise FileNotFoundError(f"File not found: {file_path}")

    print(f"Loading data from {file_path}...")
    # Using pandas to read the HDF5 key
    df = pd.read_hdf(file_path, key="data")

    # Extract signals
    ppg_raw = np.vstack(df['PPG'].values)   # (N, signal_len)
    sbp_raw = df['sbp_mean'].values          # (N,)
    dbp_raw = df['dbp_mean'].values          # (N,)

    # ------------------------------------------
    # BMI CALCULATION ADDED HERE
    # ------------------------------------------
    # Check if columns exist, otherwise raise error or fill with NaN
    if 'weight' in df.columns and 'height' in df.columns:
        weights = df['weight'].values
        heights = df['height'].values
        
        # Vectorized BMI calculation
        # Assuming height is in cm and weight is in kg
        bmi_raw = calculate_bmi(weights, heights)
        
        # Handle potential NaNs from calculation (e.g., height=0)
        nan_count = np.isnan(bmi_raw).sum()
        if nan_count > 0:
            print(f"Warning: {nan_count} entries have invalid BMI (NaN).")
    else:
        print("Warning: 'weight' or 'height' columns not found. Filling BMI with NaN.")
        bmi_raw = np.full(len(df), np.nan)

    print(f"Raw PPG shape : {ppg_raw.shape}")
    print(f"SBP labels    : {sbp_raw.shape}")
    print(f"DBP labels    : {dbp_raw.shape}")
    print(f"BMI values    : {bmi_raw.shape}")
    
    return ppg_raw, sbp_raw, dbp_raw, bmi_raw


# ==========================================
# SIGNAL PROCESSING HELPERS
# ==========================================

def bandpass_filter(signal: np.ndarray,
                    fs: float = FS,
                    low: float = 0.5,
                    high: float = 8.0) -> np.ndarray:
    """4th-order Butterworth bandpass filter (0.5–8 Hz)."""
    nyq  = 0.5 * fs
    b, a = butter(4, [low / nyq, high / nyq], btype='band')
    return filtfilt(b, a, signal)


def detect_peaks(signal: np.ndarray, fs: float = FS) -> np.ndarray:
    """
    Detect systolic peaks using adaptive prominence on the
    filtered PPG signal.
    """
    prominence = 0.3 * (np.max(signal) - np.min(signal))
    peaks, _   = find_peaks(
        signal,
        distance=int(0.35 * fs),
        prominence=max(prominence, 0.1)
    )
    return peaks


def compute_features(beat: np.ndarray) -> np.ndarray:
    """
    Convert a single beat (length = TARGET_LEN) into a
    (TARGET_LEN, 3) feature array:
      ch0 — Z-score normalised PPG
      ch1 — 1st derivative (velocity)
      ch2 — 2nd derivative (acceleration / arterial stiffness proxy)
    """
    raw_norm = (beat - np.mean(beat)) / (np.std(beat) + 1e-8)
    d1       = np.gradient(raw_norm)
    d2       = np.gradient(d1)
    return np.stack([raw_norm, d1, d2], axis=-1).astype(np.float32)


# ==========================================
# BEAT EXTRACTION
# ==========================================

def extract_beats(indices: np.ndarray,
                  ppg_raw: np.ndarray,
                  sbp_raw: np.ndarray,
                  dbp_raw: np.ndarray,
                  bmi_raw: np.ndarray):
    """
    Extract fixed-length beat segments from the windows
    indicated by `indices`.

    Returns
    -------
    X  : np.ndarray  shape (M, TARGET_LEN, 3)
    ys : np.ndarray  shape (M,)   SBP labels
    yd : np.ndarray  shape (M,)   DBP labels
    yb : np.ndarray  shape (M,)   BMI labels
    """
    beats, sbps, dbps, bmis = [], [], [], []
    
    for i in indices:
        raw    = ppg_raw[i]
        signal = bandpass_filter(raw)
        peaks  = detect_peaks(signal)

        # Get labels for this specific window i
        current_sbp = float(sbp_raw[i])
        current_dbp = float(dbp_raw[i])
        current_bmi = float(bmi_raw[i]) # BMI is constant per window/patient

        for p in peaks:
            start = p - PRE_PEAK
            end   = p + POST_PEAK
            if start >= 0 and end < len(signal):
                beat = signal[start:end]
                beats.append(compute_features(beat))
                sbps.append(current_sbp)
                dbps.append(current_dbp)
                bmis.append(current_bmi)

    X  = np.array(beats, dtype=np.float32)   # (M, 128, 3)
    ys = np.array(sbps,  dtype=np.float32)
    yd = np.array(dbps,  dtype=np.float32)
    yb = np.array(bmis,  dtype=np.float32)
    
    return X, ys, yd, yb


# ==========================================
# SEQUENCE CONSTRUCTION
# ==========================================

def make_sequences(X: np.ndarray,
                   y: np.ndarray,
                   y_bmi: np.ndarray,
                   seq_len: int = SEQ_LEN):
    """
    Slide a window of `seq_len` beats; label = last beat's BP & BMI.

    Returns
    -------
    Xs : np.ndarray  shape (N, seq_len, TARGET_LEN, 3)
    ys : np.ndarray  shape (N, 2)   [SBP, DBP]
    yb : np.ndarray  shape (N,)     BMI
    """
    Xs, ys_list, yb_list = [], [], []
    
    # Ensure we don't run out of bounds
    n_samples = len(X) - seq_len + 1
    
    for i in range(n_samples):
        Xs.append(X[i : i + seq_len])
        # BP label from the last beat in sequence
        ys_list.append(y[i + seq_len - 1])
        # BMI label from the last beat in sequence
        yb_list.append(y_bmi[i + seq_len - 1])
        
    return np.array(Xs, dtype=np.float32), np.array(ys_list, dtype=np.float32), np.array(yb_list, dtype=np.float32)


# ==========================================
# MAIN PIPELINE
# ==========================================

def build_dataset(file_path: str):
    """
    Full preprocessing pipeline.

    Returns
    -------
    X_train_seq  : (N_train, SEQ_LEN, TARGET_LEN, 3)
    X_test_seq   : (N_test,  SEQ_LEN, TARGET_LEN, 3)
    y_train_seq  : (N_train, 2)   scaled [SBP, DBP]
    y_test_seq   : (N_test,  2)   scaled [SBP, DBP]
    bmi_train    : (N_train,)     BMI values (unscaled)
    bmi_test     : (N_test,)      BMI values (unscaled)
    scaler_y     : fitted StandardScaler (needed for inverse_transform)
    """
    ppg_raw, sbp_raw, dbp_raw, bmi_raw = load_data(file_path)

    # Filter out windows with NaN BMI before splitting (optional but recommended)
    valid_mask = ~np.isnan(bmi_raw)
    if not np.all(valid_mask):
        print(f"Filtering out {np.sum(~valid_mask)} windows with invalid BMI.")
        ppg_raw = ppg_raw[valid_mask]
        sbp_raw = sbp_raw[valid_mask]
        dbp_raw = dbp_raw[valid_mask]
        bmi_raw = bmi_raw[valid_mask]

    # Window-level split (prevents beat-level data leakage)
    n_windows = len(ppg_raw)
    all_idx   = np.arange(n_windows)
    train_idx, test_idx = train_test_split(
        all_idx, test_size=0.2, random_state=42
    )
    print(f"\nWindow-level split → Train: {len(train_idx)} | Test: {len(test_idx)}")

    print("\nExtracting TRAIN beats...")
    X_train, y_sbp_train, y_dbp_train, y_bmi_train = extract_beats(
        train_idx, ppg_raw, sbp_raw, dbp_raw, bmi_raw
    )
    print("Extracting TEST beats...")
    X_test, y_sbp_test, y_dbp_test, y_bmi_test = extract_beats(
        test_idx, ppg_raw, sbp_raw, dbp_raw, bmi_raw
    )
    print(f"\nTrain beats: {X_train.shape[0]} | Test beats: {X_test.shape[0]}")

    # Scale BP labels — fit on TRAIN only
    y_train    = np.column_stack([y_sbp_train, y_dbp_train])
    y_test     = np.column_stack([y_sbp_test,  y_dbp_test])
    scaler_y   = StandardScaler()
    y_train_sc = scaler_y.fit_transform(y_train)
    y_test_sc  = scaler_y.transform(y_test)

    # Build beat sequences
    # Note: BMI is passed through but not scaled here (usually treated as metadata or auxiliary input)
    X_train_seq, y_train_seq, bmi_train_seq = make_sequences(X_train, y_train_sc, y_bmi_train)
    X_test_seq,  y_test_seq,  bmi_test_seq  = make_sequences(X_test,  y_test_sc,  y_bmi_test)
    
    print(f"\nSequence shapes → Train: {X_train_seq.shape} | Test: {X_test_seq.shape}")

    return X_train_seq, X_test_seq, y_train_seq, y_test_seq, bmi_train_seq, bmi_test_seq, scaler_y