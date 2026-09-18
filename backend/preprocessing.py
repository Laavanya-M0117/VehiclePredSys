import numpy as np
import pandas as pd

DEFAULT_PID_BOUNDS = {
    'rpm': (0.0, 14000.0),
    'coolant_temp': (-40.0, 150.0),
    'engine_load': (0.0, 100.0),
    'throttle_pos': (0.0, 100.0),
    'fuel_trim': (-100.0, 99.2),
    'o2_voltage': (0.0, 1.275),
    'speed': (0.0, 255.0),
    'voltage': (0.0, 20.0)
}

DEFAULT_FALLBACKS = {
    'rpm': 2500.0,
    'coolant_temp': 88.0,
    'engine_load': 40.0,
    'throttle_pos': 20.0,
    'fuel_trim': 0.0,
    'o2_voltage': 0.45,
    'speed': 50.0,
    'voltage': 13.8
}

def clean_and_validate_reading(reading_dict):
    """
    Validates a single OBD-II sensor reading against physical bounds.
    Fills missing or corrupted PIDs with default baseline values.
    Supports extended Royal Enfield sensor aliases (e.g. eot, tps, stft, battery_voltage).
    """
    # Normalize aliases from 15-parameter Royal Enfield protocol
    normalized = dict(reading_dict)
    if 'eot' in normalized and 'coolant_temp' not in normalized:
        normalized['coolant_temp'] = normalized['eot']
    if 'tps' in normalized and 'throttle_pos' not in normalized:
        normalized['throttle_pos'] = normalized['tps']
    if 'stft' in normalized and 'fuel_trim' not in normalized:
        normalized['fuel_trim'] = normalized['stft']
    if 'battery_voltage' in normalized and 'voltage' not in normalized:
        normalized['voltage'] = normalized['battery_voltage']
    if 'bat' in normalized and 'voltage' not in normalized:
        normalized['voltage'] = normalized['bat']
    if 'map' in normalized and 'engine_load' not in normalized:
        # Approximate engine load from MAP (100 kPa ~ 100% load at WOT)
        try:
            normalized['engine_load'] = float(normalized['map'])
        except (ValueError, TypeError):
            pass

    cleaned = {}
    for key, fallback in DEFAULT_FALLBACKS.items():
        val = normalized.get(key, None)
        if val is None or not isinstance(val, (int, float)) or np.isnan(val):
            cleaned[key] = fallback
        else:
            min_val, max_val = DEFAULT_PID_BOUNDS[key]
            cleaned[key] = float(np.clip(val, min_val, max_val))
    return cleaned

ML_FEATURE_COLS = [
    'rpm',
    'speed',
    'throttle_pos',
    'engine_load',
    'map_kpa',
    'iat',
    'coolant_temp',
    'o2_voltage',
    'fuel_trim',
    'ltft',
    'voltage',
    'gear',
    'total_fuel_trim',
    'vacuum_ratio',
    'thermal_headroom',
    'electrical_health_margin',
    'o2_lambda_deviation',
    'rpm_load_ratio',
    'gear_speed_ratio'
]

def extract_ml_features(data):
    """
    Computes domain-engineered features from raw sensor readings.
    Supports either a single dictionary (inference) or a pandas DataFrame (training).
    """
    if isinstance(data, dict):
        cleaned = clean_and_validate_reading(data)
        
        # Extract extended fields if present
        map_kpa = float(data.get('map_kpa', data.get('map', cleaned['engine_load'])))
        iat = float(data.get('iat', 32.0))
        ltft = float(data.get('ltft', 1.8))
        gear = float(data.get('gear', 0) if str(data.get('gear', 0)).isdigit() else (0.0 if str(data.get('gear')).upper() == 'N' else 1.0))
        
        # Diagnostic engineered features
        total_fuel_trim = cleaned['fuel_trim'] + ltft
        vacuum_ratio = map_kpa / (cleaned['throttle_pos'] + 1.0)
        thermal_headroom = 115.0 - cleaned['coolant_temp']
        electrical_health_margin = cleaned['voltage'] - 12.0
        o2_lambda_deviation = abs(cleaned['o2_voltage'] - 0.45)
        rpm_load_ratio = cleaned['rpm'] / (cleaned['engine_load'] + 1.0)
        gear_speed_ratio = cleaned['speed'] / (gear + 0.1)

        feat_dict = {
            'rpm': cleaned['rpm'],
            'speed': cleaned['speed'],
            'throttle_pos': cleaned['throttle_pos'],
            'engine_load': cleaned['engine_load'],
            'map_kpa': map_kpa,
            'iat': iat,
            'coolant_temp': cleaned['coolant_temp'],
            'o2_voltage': cleaned['o2_voltage'],
            'fuel_trim': cleaned['fuel_trim'],
            'ltft': ltft,
            'voltage': cleaned['voltage'],
            'gear': gear,
            'total_fuel_trim': total_fuel_trim,
            'vacuum_ratio': vacuum_ratio,
            'thermal_headroom': thermal_headroom,
            'electrical_health_margin': electrical_health_margin,
            'o2_lambda_deviation': o2_lambda_deviation,
            'rpm_load_ratio': rpm_load_ratio,
            'gear_speed_ratio': gear_speed_ratio,
        }
        return feat_dict
        
    elif isinstance(data, pd.DataFrame):
        df = data.copy()
        
        # Ensure base columns exist
        if 'map_kpa' not in df.columns:
            df['map_kpa'] = df.get('map', df['engine_load'])
        if 'iat' not in df.columns:
            df['iat'] = 32.0
        if 'ltft' not in df.columns:
            df['ltft'] = 1.8
        if 'gear' not in df.columns:
            df['gear'] = 0.0

        # Compute engineered columns vectorized
        df['total_fuel_trim'] = df['fuel_trim'] + df['ltft']
        df['vacuum_ratio'] = df['map_kpa'] / (df['throttle_pos'] + 1.0)
        df['thermal_headroom'] = 115.0 - df['coolant_temp']
        df['electrical_health_margin'] = df['voltage'] - 12.0
        df['o2_lambda_deviation'] = (df['o2_voltage'] - 0.45).abs()
        df['rpm_load_ratio'] = df['rpm'] / (df['engine_load'] + 1.0)
        df['gear_speed_ratio'] = df['speed'] / (df['gear'] + 0.1)

        return df[ML_FEATURE_COLS]

def aggregate_window_features(readings_list):
    """
    Given a list of OBD readings over a window, extracts engineered features
    and aggregates statistical summaries.
    """
    if not readings_list:
        return extract_ml_features(DEFAULT_FALLBACKS)
    
    cleaned_rows = [clean_and_validate_reading(r) for r in readings_list]
    df = pd.DataFrame(cleaned_rows)
    # Use the latest snapshot with mean smoothed features
    avg_dict = {}
    for col in DEFAULT_FALLBACKS.keys():
        avg_dict[col] = float(df[col].mean())
    # Carry forward extended features from the latest reading
    latest = readings_list[-1]
    for ext_col in ['map_kpa', 'map', 'iat', 'ltft', 'gear']:
        if ext_col in latest:
            avg_dict[ext_col] = latest[ext_col]
    return extract_ml_features(avg_dict)
