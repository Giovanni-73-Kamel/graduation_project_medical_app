
import numpy as np
import pickle
import json
import tensorflow as tf

class ECGClassifier:
    def __init__(self, model_dir):
        self.model_dir = model_dir
        self._load_artifacts()
    
    def _load_artifacts(self):
        self.model = tf.keras.models.load_model(f"{self.model_dir}/aami_mitbih_cnn_with_confidence.keras")
        
        with open(f"{self.model_dir}/scaler_with_confidence.pkl", "rb") as f:
            self.scaler = pickle.load(f)
        
        with open(f"{self.model_dir}/config.json", "r") as f:
            self.config = json.load(f)
        
        self.thresholds = self.config["optimal_thresholds"]
        self.class_names = self.config["class_names"]
    
    def preprocess(self, ecg_signal):
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
