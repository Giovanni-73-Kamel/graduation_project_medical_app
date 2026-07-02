
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
            f"{self.model_dir}/aami_mitbih_cnn_with_confidence.keras",
            custom_objects={"ConfidenceLayer": ConfidenceLayer},
            compile=False,
        )
        
        with open(f"{self.model_dir}/scaler_with_confidence.pkl", "rb") as f:
            try:
                self.scaler = pickle.load(f)
            except pickle.UnpicklingError:
                import joblib

                f.seek(0)
                self.scaler = joblib.load(f)
        
        with open(f"{self.model_dir}/config.json", "r") as f:
            self.config = json.load(f)
        
        self.thresholds = self.config["optimal_thresholds"]
        self.class_names = self.config["class_names"]
    
    def preprocess(self, ecg_signal):
        ecg_signal = np.asarray(ecg_signal, dtype=np.float32)
        # Signal should be 1D array of length 186
        if ecg_signal.ndim == 1:
            ecg_signal = ecg_signal.reshape(1, -1)
        
        ecg_scaled = self.scaler.transform(ecg_signal)
        return ecg_scaled.reshape(1, 186, 1)
    
    def predict(self, ecg_signal):
        processed = self.preprocess(ecg_signal)
        probabilities, confidences = self.model.predict(processed, verbose=0)
        
        results = {}
        for i, cls in enumerate(self.class_names):
            prob = float(probabilities[0][i])
            conf = float(confidences[0][i])
            thresh = float(self.thresholds[cls])
            
            results[cls] = {
                "detected": bool(prob >= thresh),
                "probability": round(prob, 4),
                "confidence": round(conf, 4)
            }
        
        return results

if __name__ == "__main__":
    # Example Usage
    classifier = ECGClassifier(r"D:\machine_learning\mitbih_processed")
    # Load a fake signal or real signal here
    signal = np.random.randn(186)
    print(json.dumps(classifier.predict(signal), indent=2))
