import os
import sys
import numpy as np

repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if repo_root not in sys.path:
    sys.path.insert(0, repo_root)

from backend.preprocessing import clean_and_validate_reading, aggregate_window_features
from backend.triage import evaluate_sensor_triage, compute_health_score
from backend.dataset_generator import generate_obd_dataset
from backend.train_baseline_model import train_and_save_models
from backend.inference import PredictiveTriageInference

def run_all_tests():
    print("[Test Pipeline] Testing dataset generator...")
    df = generate_obd_dataset(n_samples=100)
    assert len(df) == 100
    assert 'rpm' in df.columns
    assert 'coolant_temp' in df.columns
    assert 'target_label' in df.columns

    print("[Test Pipeline] Testing preprocessing and bounds...")
    raw_bad_reading = {
        'rpm': -500.0,
        'coolant_temp': 999.0,
        'voltage': np.nan
    }
    cleaned = clean_and_validate_reading(raw_bad_reading)
    assert cleaned['rpm'] == 0.0
    assert cleaned['coolant_temp'] == 150.0
    assert cleaned['voltage'] == 13.8

    print("[Test Pipeline] Testing triage engine...")
    normal_reading = {'coolant_temp': 88.0, 'fuel_trim': 1.0, 'voltage': 13.8, 'o2_voltage': 0.5}
    label, dtcs = evaluate_sensor_triage(normal_reading)
    assert label == "NORMAL"
    assert len(dtcs) == 0

    overheat_reading = {'coolant_temp': 118.0, 'fuel_trim': 2.0, 'voltage': 13.5, 'o2_voltage': 0.4}
    label, dtcs = evaluate_sensor_triage(overheat_reading)
    assert label == "CRITICAL"
    assert any(d['code'] == 'P0217' for d in dtcs)

    score = compute_health_score(failure_prob=0.8, active_dtcs=dtcs, coolant_temp=118.0, voltage=13.5)
    assert 0 <= score <= 50

    print("[Test Pipeline] Testing ML model training and inference...")
    backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '../backend'))
    models_dir = os.path.join(backend_dir, 'models')
    
    metadata = train_and_save_models(models_dir=models_dir)
    assert metadata['val_auc'] > 0.70

    inference_engine = PredictiveTriageInference(models_dir=models_dir)
    assert inference_engine.model_loaded is True

    prediction = inference_engine.predict({'rpm': 3500, 'coolant_temp': 90, 'voltage': 13.8})
    assert 'health_score' in prediction
    assert 0 <= prediction['health_score'] <= 100

    print("\n[SUCCESS] ALL PIPELINE TESTS PASSED CLEANLY!")

if __name__ == '__main__':
    run_all_tests()
