import numpy as np
import os
import csv
import pandas as pd

class SimpleDataset:
    def __init__(self, data_dict):
        self._data = {k: np.array(v) for k, v in data_dict.items()}
        lengths = {len(v) for v in self._data.values()}
        if len(lengths) != 1:
            raise ValueError("All dataset columns must have the same length")
        self.columns = list(self._data.keys())
        self._length = next(iter(lengths))

    def __len__(self):
        return self._length

    def __getitem__(self, key):
        if isinstance(key, (list, tuple)):
            return np.column_stack([self._data[k] for k in key])
        return self._data[key]

    def to_pandas(self):
        return pd.DataFrame(self._data)


def generate_obd_dataset(n_samples=10000, random_seed=42):
    """
    Generates physically correlated OBD-II sensor data calibrated to the
    Royal Enfield Classic 350 (J-Series 349cc single-cylinder EFI engine).

    Simulates 4 distinct operating states & failure trajectories:
      0: Normal / Healthy Operation (Closed loop, correlated load, normal thermal curve)
      1: Thermal / Overheating Fault (P0217 - Oil/coolant overtemp, excessive thermal slope)
      2: Vacuum Leak / Lean Misfire (P0171, P0300 - High MAP at low TPS, pegged high STFT)
      3: Electrical Stator/Battery Failure (P0562 - Charging system breakdown, voltage sag)
    """
    np.random.seed(random_seed)
    
    # Class proportions: 60% normal, 15% overheat, 15% lean/misfire, 10% electrical
    labels = np.random.choice([0, 1, 2, 3], size=n_samples, p=[0.60, 0.15, 0.15, 0.10])
    
    # Core 15 parameters
    rpm_list = []
    speed_list = []
    tps_list = []
    map_list = []
    iat_list = []
    eot_list = []
    o2_list = []
    stft_list = []
    ltft_list = []
    battery_list = []
    gear_list = []
    clutch_list = []
    sidestand_list = []
    fwheel_list = []
    rwheel_list = []
    
    # Derived engine load
    engine_load_list = []
    
    # Failure outputs
    rul_list = []
    prob_list = []
    
    gear_speed_factors = {
        0: 0.0,     # Neutral
        1: 0.0078,  # ~15.6 km/h at 2000 RPM
        2: 0.0120,  # ~24.0 km/h at 2000 RPM
        3: 0.0165,  # ~33.0 km/h at 2000 RPM
        4: 0.0213,  # ~42.6 km/h at 2000 RPM
        5: 0.0263   # ~52.6 km/h at 2000 RPM
    }

    for label in labels:
        ambient_temp = np.random.uniform(24.0, 36.0)
        iat = ambient_temp + np.random.normal(3.0, 1.0)
        
        # Decide driving mode: 0=idle, 1=city, 2=cruising, 3=hard acceleration
        mode = np.random.choice([0, 1, 2, 3], p=[0.25, 0.40, 0.25, 0.10])
        
        # Determine baseline physics based on mode
        if mode == 0:  # Idle
            gear = 0
            rpm = np.random.normal(1050, 25)
            tps = np.random.uniform(1.8, 2.5)
            map_kpa = np.random.normal(34.0, 2.5)
            speed = 0.0
            clutch = 0
            sidestand = np.random.choice([0, 1], p=[0.8, 0.2])
        elif mode == 1:  # City riding (Gears 1-3)
            gear = np.random.choice([1, 2, 3], p=[0.3, 0.4, 0.3])
            tps = np.random.uniform(6.0, 22.0)
            map_kpa = np.random.normal(48.0, 6.0)
            rpm = np.random.normal(2400, 400)
            speed = rpm * gear_speed_factors[gear] + np.random.normal(0, 1.5)
            clutch = 0
            sidestand = 0
        elif mode == 2:  # Cruising (Gears 4-5)
            gear = np.random.choice([4, 5], p=[0.35, 0.65])
            tps = np.random.uniform(14.0, 35.0)
            map_kpa = np.random.normal(62.0, 5.0)
            rpm = np.random.normal(3400, 350)
            speed = rpm * gear_speed_factors[gear] + np.random.normal(0, 2.0)
            clutch = 0
            sidestand = 0
        else:  # Hard acceleration
            gear = np.random.choice([2, 3, 4], p=[0.4, 0.4, 0.2])
            tps = np.random.uniform(40.0, 85.0)
            map_kpa = np.random.normal(82.0, 6.0)
            rpm = np.random.normal(4400, 500)
            speed = rpm * gear_speed_factors[gear] + np.random.normal(0, 2.5)
            clutch = 0
            sidestand = 0

        # Calculate physically correlated engine load (% based on MAP vs ambient atmospheric pressure)
        engine_load = float(np.clip((map_kpa / 100.0) * 100.0 + np.random.normal(0, 2.0), 10.0, 100.0))

        # ==============================================================
        # Apply State & Fault Dynamics
        # ==============================================================
        if label == 0:  # NORMAL HEALTHY
            eot = np.random.normal(88.0, 3.5) if mode > 0 else np.random.normal(86.0, 2.5)
            stft = np.random.normal(1.8, 1.5)
            ltft = np.random.normal(1.5, 0.8)
            o2 = np.random.choice([np.random.uniform(0.68, 0.88), np.random.uniform(0.18, 0.35)])
            bat = np.random.normal(14.15, 0.12) if rpm > 1200 else np.random.normal(14.05, 0.08)
            rul = np.random.uniform(700.0, 1500.0)
            fail_prob = np.random.uniform(0.01, 0.08)

        elif label == 1:  # OVERHEATING FAULT (P0217)
            # High thermal runaway: EOT climbs beyond normal oil limits
            eot = np.random.normal(116.0, 5.0)
            iat += np.random.uniform(5.0, 12.0)
            # ECU injects extra fuel to cool cylinder wall
            stft = np.random.normal(7.5, 2.5)
            ltft = np.random.normal(4.0, 1.2)
            o2 = np.random.uniform(0.65, 0.90)  # slightly rich bias
            bat = np.random.normal(13.85, 0.20)
            rul = np.random.uniform(8.0, 75.0)
            fail_prob = np.random.uniform(0.72, 0.96)

        elif label == 2:  # VACUUM LEAK / LEAN MISFIRE (P0171 / P0300)
            # Unmetered air: MAP is abnormally high relative to low throttle
            map_kpa = np.clip(map_kpa + np.random.uniform(18.0, 32.0), 20.0, 98.0)
            eot = np.random.normal(94.0, 4.0)  # Lean combustion runs hot
            # Massive positive fuel trim attempt by ECU
            stft = np.random.normal(19.5, 3.5)
            ltft = np.random.normal(14.0, 2.0)
            o2 = np.random.uniform(0.05, 0.20)  # Pinned lean
            # RPM fluctuation due to misfire
            rpm = max(850.0, rpm + np.random.normal(0, 180.0))
            bat = np.random.normal(13.95, 0.18)
            rul = np.random.uniform(20.0, 120.0)
            fail_prob = np.random.uniform(0.65, 0.92)

        else:  # ELECTRICAL / STATOR / BATTERY DEGRADATION (P0562)
            eot = np.random.normal(87.0, 3.0)
            stft = np.random.normal(1.0, 2.0)
            ltft = np.random.normal(1.2, 1.0)
            o2 = np.random.uniform(0.20, 0.70)
            # Severe charging system failure: voltage collapses below 11.5V
            bat = np.random.normal(10.6, 0.45)
            rul = np.random.uniform(4.0, 45.0)
            fail_prob = np.random.uniform(0.80, 0.99)

        # Physical boundary clipping
        rpm = float(np.clip(rpm, 800.0, 6800.0))
        speed = float(np.clip(speed, 0.0, 135.0))
        tps = float(np.clip(tps, 0.0, 100.0))
        map_kpa = float(np.clip(map_kpa, 20.0, 105.0))
        iat = float(np.clip(iat, 10.0, 65.0))
        eot = float(np.clip(eot, 40.0, 135.0))
        o2 = float(np.clip(o2, 0.02, 1.10))
        stft = float(np.clip(stft, -25.0, 35.0))
        ltft = float(np.clip(ltft, -20.0, 25.0))
        bat = float(np.clip(bat, 8.5, 15.5))
        
        # Wheel speed sensors with realistic slip
        fwheel = speed
        rwheel = float(np.clip(speed * np.random.uniform(0.98, 1.02), 0.0, 140.0))

        # Append to collections
        rpm_list.append(round(rpm, 1))
        speed_list.append(round(speed, 1))
        tps_list.append(round(tps, 1))
        map_list.append(round(map_kpa, 1))
        iat_list.append(round(iat, 1))
        eot_list.append(round(eot, 1))
        o2_list.append(round(o2, 3))
        stft_list.append(round(stft, 2))
        ltft_list.append(round(ltft, 2))
        battery_list.append(round(bat, 2))
        gear_list.append(int(gear))
        clutch_list.append(int(clutch))
        sidestand_list.append(int(sidestand))
        fwheel_list.append(round(fwheel, 1))
        rwheel_list.append(round(rwheel, 1))
        engine_load_list.append(round(engine_load, 1))
        rul_list.append(round(rul, 1))
        prob_list.append(round(fail_prob, 4))

    data = {
        'rpm': rpm_list,
        'speed': speed_list,
        'throttle_pos': tps_list,
        'engine_load': engine_load_list,
        'map_kpa': map_list,
        'iat': iat_list,
        'coolant_temp': eot_list,
        'o2_voltage': o2_list,
        'fuel_trim': stft_list,
        'ltft': ltft_list,
        'voltage': battery_list,
        'gear': gear_list,
        'clutch': clutch_list,
        'side_stand': sidestand_list,
        'front_wheel_speed': fwheel_list,
        'rear_wheel_speed': rwheel_list,
        'target_label': labels,
        'rul_hours': rul_list,
        'failure_probability': prob_list
    }

    return SimpleDataset(data)


if __name__ == '__main__':
    data_dir = os.path.join(os.path.dirname(__file__), '..', 'data')
    os.makedirs(data_dir, exist_ok=True)
    
    print("[Dataset Generator] Synthesizing physically-correlated Royal Enfield J-Series dataset...")
    ds = generate_obd_dataset(n_samples=10000, random_seed=42)
    csv_path = os.path.join(data_dir, 're_classic350_physical_dataset.csv')
    
    df = ds.to_pandas()
    df.to_csv(csv_path, index=False)
    print(f"[Dataset Generator] [SUCCESS] Successfully generated {len(df)} records saved to {csv_path}")
    print(df.describe().T[['mean', 'std', 'min', 'max']])
