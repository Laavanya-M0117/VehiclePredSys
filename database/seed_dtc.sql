-- Seed Standard SAE Diagnostic Trouble Codes (DTCs)

INSERT INTO dtc_lookup (code, title, description, default_severity) VALUES
('P0300', 'Multiple Cylinder Misfire Detected', 'Engine misfire detected across one or more cylinders. Potential catalyst damage.', 'CRITICAL'),
('P0171', 'Fuel System Lean (Bank 1)', 'Air/Fuel ratio is excessively lean. Check vacuum lines and intake manifold.', 'WARNING'),
('P0217', 'Engine Coolant Over Temperature Condition', 'Coolant temperature exceeded threshold (>115C). Risk of cylinder head warping.', 'CRITICAL'),
('P0562', 'System Voltage Low', 'Battery or stator charging system output dropped below 11.5 Volts.', 'WARNING'),
('P0420', 'Catalyst System Efficiency Below Threshold', 'Exhaust emissions degradation or faulty oxygen sensor.', 'INFO'),
('P0105', 'Manifold Absolute Pressure Circuit Malfunction', 'MAP sensor voltage input out of bounds.', 'WARNING'),
('P0117', 'Engine Coolant Temperature Sensor 1 Circuit Low', 'ECT sensor short to ground or engine overheating.', 'CRITICAL'),
('P0122', 'Throttle/Pedal Position Sensor A Circuit Low', 'TPS voltage output below threshold.', 'WARNING')
ON CONFLICT (code) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  default_severity = EXCLUDED.default_severity;
