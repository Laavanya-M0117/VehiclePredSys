import sys
import os
import json

# Ensure project root is on sys.path
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from backend.inference import get_inference_engine

def run_e2e_tests():
    print("==================================================================")
    print("VETRI: END-TO-END PREDICTIVE TRIAGE ML PIPELINE VERIFICATION")
    print("==================================================================")
    
    engine = get_inference_engine()
    assert engine.model_loaded, "Error: Trained ML models must be loaded!"
    print(f"Models successfully loaded: {engine.model_loaded}")
    print(f"Metadata features: {len(engine.metadata.get('features', []))}")

    # Test Case 1: Normal Royal Enfield Classic 350 Idle Telemetry (from actual BLE log)
    normal_reading = {
        'rpm': 1058.0,
        'speed': 0.0,
        'tps': 2.1,
        'throttle_pos': 2.1,
        'map': 34.0,
        'iat': 31.0,
        'eot': 88.0,
        'coolant_temp': 88.0,
        'o2_voltage': 0.36,
        'stft': 2.3,
        'fuel_trim': 2.3,
        'ltft': 1.8,
        'bat': 14.12,
        'voltage': 14.12,
        'gear': 'N',
        'clutch': 0,
        'side_stand': 0,
        'f_wheel': 0.0,
        'r_wheel': 0.0,
        'dtc': 'NO FAULT'
    }

    res1 = engine.predict(normal_reading)
    print("\n--- TEST CASE 1: NORMAL IDLE ---")
    print(f"Triage: {res1['triage_label']}")
    print(f"Fault Class: {res1['predicted_fault_class']}")
    print(f"Failure Prob: {res1['failure_probability']:.4f}")
    print(f"RUL: {res1['rul_hours']} hrs")
    print(f"Health Score: {res1['health_score']}")
    print(f"Explanation: {res1['diagnostic_explanation']}")
    assert res1['triage_label'] in ['LOW', 'NORMAL'], f"Unexpected triage: {res1['triage_label']}"
    assert res1['predicted_fault_class'] == 'NORMAL'

    # Test Case 2: Overheating Fault (Thermal Runaway / Oil Degradation)
    overheat_reading = {
        'rpm': 4200.0,
        'speed': 72.0,
        'tps': 38.0,
        'throttle_pos': 38.0,
        'map': 68.0,
        'iat': 42.0,
        'eot': 126.5,  # High oil temp
        'coolant_temp': 126.5,
        'o2_voltage': 0.45,
        'stft': 4.1,
        'fuel_trim': 4.1,
        'ltft': 5.2,
        'bat': 13.9,
        'voltage': 13.9,
        'gear': '4',
        'clutch': 0,
        'side_stand': 0,
        'f_wheel': 72.0,
        'r_wheel': 72.0,
        'dtc': 'P0217'
    }

    res2 = engine.predict(overheat_reading)
    print("\n--- TEST CASE 2: OVERHEATING FAULT (P0217) ---")
    print(f"Triage: {res2['triage_label']}")
    print(f"Fault Class: {res2['predicted_fault_class']}")
    print(f"Failure Prob: {res2['failure_probability']:.4f}")
    print(f"RUL: {res2['rul_hours']} hrs")
    print(f"Health Score: {res2['health_score']}")
    print(f"Explanation: {res2['diagnostic_explanation']}")
    assert res2['predicted_fault_class'] == 'OVERHEATING_FAULT'
    assert res2['triage_label'] in ['HIGH', 'CRITICAL']
    assert res2['failure_probability'] > 0.60

    # Test Case 3: Intake Vacuum Leak / Lean Misfire
    leak_reading = {
        'rpm': 1600.0,
        'speed': 15.0,
        'tps': 3.0,
        'throttle_pos': 3.0,
        'map': 62.0,  # abnormally high MAP for 3% TPS (poor vacuum)
        'iat': 33.0,
        'eot': 92.0,
        'coolant_temp': 92.0,
        'o2_voltage': 0.12,  # lean O2
        'stft': 22.5,  # extreme positive trim
        'fuel_trim': 22.5,
        'ltft': 14.8,
        'bat': 14.05,
        'voltage': 14.05,
        'gear': '1',
        'clutch': 0,
        'side_stand': 0,
        'f_wheel': 15.0,
        'r_wheel': 15.0,
        'dtc': 'P0171'
    }

    res3 = engine.predict(leak_reading)
    print("\n--- TEST CASE 3: INTAKE VACUUM LEAK (P0171) ---")
    print(f"Triage: {res3['triage_label']}")
    print(f"Fault Class: {res3['predicted_fault_class']}")
    print(f"Failure Prob: {res3['failure_probability']:.4f}")
    print(f"RUL: {res3['rul_hours']} hrs")
    print(f"Health Score: {res3['health_score']}")
    print(f"Explanation: {res3['diagnostic_explanation']}")
    assert res3['predicted_fault_class'] == 'LEAN_MISFIRE_FAULT'
    assert res3['triage_label'] in ['MEDIUM', 'HIGH']

    # Test Case 4: Electrical Breakdown / Stator Failure
    electrical_reading = {
        'rpm': 3100.0,
        'speed': 48.0,
        'tps': 22.0,
        'throttle_pos': 22.0,
        'map': 48.0,
        'iat': 32.0,
        'eot': 89.0,
        'coolant_temp': 89.0,
        'o2_voltage': 0.44,
        'stft': 1.2,
        'fuel_trim': 1.2,
        'ltft': 1.0,
        'bat': 10.75,  # failing battery / dead alternator
        'voltage': 10.75,
        'gear': '3',
        'clutch': 0,
        'side_stand': 0,
        'f_wheel': 48.0,
        'r_wheel': 48.0,
        'dtc': 'P0562'
    }

    res4 = engine.predict(electrical_reading)
    print("\n--- TEST CASE 4: ELECTRICAL CHARGING FAILURE (P0562) ---")
    print(f"Triage: {res4['triage_label']}")
    print(f"Fault Class: {res4['predicted_fault_class']}")
    print(f"Failure Prob: {res4['failure_probability']:.4f}")
    print(f"RUL: {res4['rul_hours']} hrs")
    print(f"Health Score: {res4['health_score']}")
    print(f"Explanation: {res4['diagnostic_explanation']}")
    assert res4['predicted_fault_class'] == 'ELECTRICAL_FAULT'
    assert res4['triage_label'] in ['HIGH', 'CRITICAL']

    print("\n==================================================================")
    print("ALL 4 REAL-TIME ML PREDICTION VERIFICATIONS PASSED WITH 100% ACCURACY!")
    print("==================================================================")

if __name__ == '__main__':
    run_e2e_tests()
