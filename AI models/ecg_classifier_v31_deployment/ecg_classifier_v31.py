"""
ECG Arrhythmia Classifier v3.1 — Server Deployment Module
Uses TTA (6 rounds) for best accuracy on server infrastructure.
"""
import numpy as np
import pickle
import json
import tensorflow as tf


@tf.keras.utils.register_keras_serializable()
class ConfidenceLayer(tf.keras.layers.Layer):
    def __init__(self, thresholds=None, **kwargs):
        super().__init__(**kwargs)
        self.thresholds = thresholds or []

    def call(self, inputs):
        thresholds = tf.constant(self.thresholds, dtype=inputs.dtype)
        confidence = tf.where(
            inputs >= thresholds,
            (inputs - thresholds) / (1.0 - thresholds + 1e-7),
            (thresholds - inputs) / (thresholds + 1e-7),
        )
        return tf.clip_by_value(confidence, 0.0, 1.0)

    def get_config(self):
        config = super().get_config()
        config.update({"thresholds": self.thresholds})
        return config


class ECGClassifier:
    def __init__(self, model_dir):
        self.model_dir = model_dir
        self._load_artifacts()

    def _load_artifacts(self):
        self.model = tf.keras.models.load_model(
            f"{self.model_dir}/arrhythmia_model_v31_with_confidence.keras",
            custom_objects={"ConfidenceLayer": ConfidenceLayer},
            compile=False,
        )
        with open(f"{self.model_dir}/scaler.pkl", "rb") as f:
            self.scaler = pickle.load(f)
        with open(f"{self.model_dir}/config.json", "r") as f:
            self.config = json.load(f)
        self.thresholds   = self.config["optimal_thresholds"]
        self.class_names  = self.config["class_names"]
        self.expected_len = self.config["input_shape"][0]
        self.tta_rounds   = self.config.get("tta_rounds", 6)

    def preprocess(self, ecg_signal):
        ecg_signal = np.asarray(ecg_signal, dtype=np.float32)
        if ecg_signal.ndim == 1:
            ecg_signal = ecg_signal.reshape(1, -1)
        if ecg_signal.shape[1] != self.expected_len:
            ecg_signal = np.interp(
                np.linspace(0, self.expected_len - 1, self.expected_len),
                np.linspace(0, ecg_signal.shape[1] - 1, ecg_signal.shape[1]),
                ecg_signal[0]
            ).reshape(1, -1)
        ecg_scaled = self.scaler.transform(ecg_signal)
        return ecg_scaled.reshape(1, self.expected_len, 1)

    def predict(self, ecg_signal, use_tta=True):
        processed = self.preprocess(ecg_signal)

        if use_tta:
            # Original pass
            all_probs = [self.model.predict(processed, verbose=0)[0]]
            # TTA passes with calibrated noise
            for _ in range(self.tta_rounds):
                noise = np.random.normal(0, 0.015, processed.shape).astype(np.float32)
                all_probs.append(self.model.predict(processed + noise, verbose=0)[0])
            probabilities = np.mean(all_probs, axis=0).reshape(1, -1)
            # Recompute confidence from averaged probabilities
            confidences = np.zeros_like(probabilities)
            for i, cls in enumerate(self.class_names):
                thresh = float(self.thresholds[cls])
                prob   = probabilities[0][i]
                if prob >= thresh:
                    confidences[0][i] = (prob - thresh) / (1.0 - thresh + 1e-7)
                else:
                    confidences[0][i] = (thresh - prob) / (thresh + 1e-7)
            confidences = np.clip(confidences, 0.0, 1.0)
        else:
            probabilities, confidences = self.model.predict(processed, verbose=0)

        results = {}
        for i, cls in enumerate(self.class_names):
            prob   = float(probabilities[0][i])
            conf   = float(confidences[0][i])
            thresh = float(self.thresholds[cls])
            results[cls] = {
                "detected":     bool(prob >= thresh),
                "probability":  round(prob, 4),
                "confidence":   round(conf, 4),
                "threshold":    thresh
            }
        return results

if __name__ == "__main__":
    classifier = ECGClassifier("./ECG_Deployment_Artifacts_v31")
    ecg_signal = np.random.randn(1250)
    results    = classifier.predict(ecg_signal, use_tta=True)
    import json
    print(json.dumps(results, indent=2))
