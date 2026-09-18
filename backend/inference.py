import os
import joblib
import numpy as np
import pandas as pd

from .preprocessing import clean_and_validate_reading, aggregate_window_features, extract_ml_features, ML_FEATURE_COLS
from .triage import evaluate_sensor_triage, compute_health_score

DEFAULT_MODELS_DIR = os.path.join(os.path.dirname(__file__), 'models')

FAULT_CLASS_LABELS = {
    0: "NORMAL",
    1: "OVERHEATING_FAULT",
    2: "LEAN_MISFIRE_FAULT",
    3: "ELECTRICAL_FAULT"
}

class PredictiveTriageInference:
    def __init__(self, models_dir=None):
        self.models_dir = models_dir if models_dir is not None else DEFAULT_MODELS_DIR
        self.clf = None
        self.reg_rul = None
        self.reg_prob = None
        self.model_loaded = False
        self.metadata = {}
        self.load_models()

    def load_models(self):
        try:
            clf_path = os.path.join(self.models_dir, 'triage_classifier.joblib')
            rul_path = os.path.join(self.models_dir, 'rul_regressor.joblib')
            prob_path = os.path.join(self.models_dir, 'prob_regressor.joblib')
            meta_path = os.path.join(self.models_dir, 'model_metadata.joblib')
            
            if os.path.exists(clf_path) and os.path.exists(rul_path) and os.path.exists(prob_path):
                self.clf = joblib.load(clf_path)
                self.reg_rul = joblib.load(rul_path)
                self.reg_prob = joblib.load(prob_path)
                if os.path.exists(meta_path):
                    self.metadata = joblib.load(meta_path)
                self.model_loaded = True
                print(f"[Inference] Successfully loaded 19-feature trained ML models from {self.models_dir}.")
            else:
                print(f"[Inference] Model artifacts not found at {self.models_dir}. Operating in heuristic fallback mode.")
        except Exception as e:
            print(f"[Inference] Error loading models ({str(e)}). Using heuristic fallback mode.")

    def predict(self, sensor_reading_or_list):
        if isinstance(sensor_reading_or_list, list):
            cleaned_single = aggregate_window_features(sensor_reading_or_list)
        else:
            cleaned_single = clean_and_validate_reading(sensor_reading_or_list)

        rule_triage, active_dtcs = evaluate_sensor_triage(cleaned_single)

        # Extract all 19 domain-engineered diagnostic features
        feat_dict = extract_ml_features(cleaned_single)
        features_df = pd.DataFrame([[feat_dict[c] for c in ML_FEATURE_COLS]], columns=ML_FEATURE_COLS)

        predicted_class_idx = 0
        predicted_class_name = "NORMAL"
        class_probabilities = [0.95, 0.02, 0.02, 0.01]

        if self.model_loaded:
            try:
                fail_prob = float(np.clip(self.reg_prob.predict(features_df)[0], 0.0, 1.0))
                rul_hrs = float(np.maximum(0.0, self.reg_rul.predict(features_df)[0]))
                
                # Multi-class prediction
                predicted_class_idx = int(self.clf.predict(features_df)[0])
                predicted_class_name = FAULT_CLASS_LABELS.get(predicted_class_idx, "NORMAL")
                class_probabilities = [round(float(p), 4) for p in self.clf.predict_proba(features_df)[0]]
            except Exception as e:
                print(f"[Inference] Prediction exception ({e}). Fallback to rule estimates.")
                fail_prob = 0.85 if rule_triage in ["CRITICAL", "HIGH"] else 0.05
                rul_hrs = 45.0 if rule_triage in ["CRITICAL", "HIGH"] else 1200.0
        else:
            fail_prob = 0.85 if rule_triage in ["CRITICAL", "HIGH"] else 0.05
            rul_hrs = 45.0 if rule_triage in ["CRITICAL", "HIGH"] else 1200.0

        # Harmonize rule triage with ML classification
        final_triage = rule_triage
        if predicted_class_idx != 0 and fail_prob > 0.60:
            if predicted_class_idx == 1 or fail_prob > 0.85:
                final_triage = "HIGH"
            else:
                final_triage = "MEDIUM"
        elif rule_triage == "NORMAL" and fail_prob <= 0.25:
            final_triage = "LOW"

        health_score = compute_health_score(
            failure_prob=fail_prob,
            active_dtcs=active_dtcs,
            coolant_temp=cleaned_single['coolant_temp'],
            voltage=cleaned_single['voltage']
        )

        # Generate diagnostic explanation
        reasons = []
        if predicted_class_idx == 1:
            reasons.append(f"Thermal distress detected: EOT at {cleaned_single['coolant_temp']}°C exceeds safe margin.")
        elif predicted_class_idx == 2:
            reasons.append(f"Intake vacuum leak / lean trim: STFT {cleaned_single['fuel_trim']:+.1f}% with vacuum ratio {feat_dict['vacuum_ratio']:.1f}.")
        elif predicted_class_idx == 3:
            reasons.append(f"Electrical charging breakdown: System voltage dropped to {cleaned_single['voltage']:.2f}V.")
        else:
            reasons.append("All mechanical and electrical telemetry parameters within nominal J-Series baseline.")

        return {
            'health_score': health_score,
            'triage_label': final_triage,
            'predicted_fault_class': predicted_class_name,
            'class_probabilities': {
                'NORMAL': class_probabilities[0],
                'OVERHEAT': class_probabilities[1],
                'LEAN_MISFIRE': class_probabilities[2],
                'ELECTRICAL': class_probabilities[3]
            },
            'rul_hours': round(rul_hrs, 1),
            'failure_probability': round(fail_prob, 4),
            'active_dtcs': active_dtcs,
            'diagnostic_explanation': " ".join(reasons),
            'model_version': 'HistGradientBoosting v2.0 (19 Features)' if self.model_loaded else 'RuleHeuristic v1.0',
            'engineered_features': {
                'vacuum_ratio': round(feat_dict['vacuum_ratio'], 2),
                'total_fuel_trim': round(feat_dict['total_fuel_trim'], 2),
                'thermal_headroom': round(feat_dict['thermal_headroom'], 1),
                'electrical_margin': round(feat_dict['electrical_health_margin'], 2)
            },
            'sensor_snapshot': cleaned_single
        }

_inference_engine = None

def get_inference_engine():
    global _inference_engine
    if _inference_engine is None:
        _inference_engine = PredictiveTriageInference()
    return _inference_engine
