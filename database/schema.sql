-- Vehicle Predictive Triage Database Schema
-- Compatible with Supabase Postgres

-- 1. Users Table (Supabase Auth reference)
CREATE TABLE IF NOT EXISTS users (
  user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  display_name TEXT,
  emergency_contact_phone TEXT,
  created_at TIMESTAMP DEFAULT now()
);

-- 2. Vehicles Table
CREATE TABLE IF NOT EXISTS vehicles (
  vehicle_id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
  nickname TEXT,
  make_model TEXT,
  odometer_km INT DEFAULT 0,
  ble_adapter_id TEXT, -- registered adapter BLE MAC/UUID
  registered_at TIMESTAMP DEFAULT now()
);

-- 3. Raw OBD-II Telemetry Readings
CREATE TABLE IF NOT EXISTS readings (
  reading_id BIGSERIAL PRIMARY KEY,
  vehicle_id INT REFERENCES vehicles(vehicle_id) ON DELETE CASCADE,
  timestamp TIMESTAMP NOT NULL DEFAULT now(),
  rpm FLOAT,
  coolant_temp FLOAT,
  engine_load FLOAT,
  throttle_pos FLOAT,
  fuel_trim FLOAT,
  o2_voltage FLOAT,
  speed FLOAT,
  voltage FLOAT
);

-- 4. ML Predictions
CREATE TABLE IF NOT EXISTS predictions (
  prediction_id BIGSERIAL PRIMARY KEY,
  vehicle_id INT REFERENCES vehicles(vehicle_id) ON DELETE CASCADE,
  predicted_at TIMESTAMP DEFAULT now(),
  health_score INT CHECK (health_score BETWEEN 0 AND 100),
  triage_label TEXT CHECK (triage_label IN ('NORMAL', 'WARNING', 'CRITICAL', 'INFO')),
  rul_hours FLOAT,
  failure_probability FLOAT,
  model_version TEXT
);

-- 5. DTC Fault Code Lookup Table
CREATE TABLE IF NOT EXISTS dtc_lookup (
  code TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  default_severity TEXT CHECK (default_severity IN ('NORMAL', 'WARNING', 'CRITICAL', 'INFO'))
);

-- 6. Alerts Table
CREATE TABLE IF NOT EXISTS alerts (
  alert_id BIGSERIAL PRIMARY KEY,
  vehicle_id INT REFERENCES vehicles(vehicle_id) ON DELETE CASCADE,
  dtc_code TEXT REFERENCES dtc_lookup(code),
  severity TEXT CHECK (severity IN ('NORMAL', 'WARNING', 'CRITICAL', 'INFO')),
  triggered_at TIMESTAMP DEFAULT now(),
  resolved BOOLEAN DEFAULT false
);

-- 7. Trips Table
CREATE TABLE IF NOT EXISTS trips (
  trip_id BIGSERIAL PRIMARY KEY,
  vehicle_id INT REFERENCES vehicles(vehicle_id) ON DELETE CASCADE,
  started_at TIMESTAMP,
  ended_at TIMESTAMP,
  distance_km FLOAT DEFAULT 0.0,
  avg_score INT,
  fuel_used_l FLOAT DEFAULT 0.0
);

-- 8. Model Training Runs Audit Log
CREATE TABLE IF NOT EXISTS training_runs (
  run_id SERIAL PRIMARY KEY,
  run_at TIMESTAMP DEFAULT now(),
  n_readings_used INT,
  val_auc FLOAT,
  val_mae FLOAT,
  notes TEXT
);
