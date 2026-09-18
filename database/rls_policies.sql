-- Row-Level Security (RLS) Policies
-- Enforces data isolation at the database layer so users can only access their own vehicles and readings.

-- Enable RLS on vehicles
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
CREATE POLICY vehicles_owner_only ON vehicles
  FOR ALL USING (user_id = auth.uid());

-- Enable RLS on readings (joins through vehicles table)
ALTER TABLE readings ENABLE ROW LEVEL SECURITY;
CREATE POLICY readings_owner_only ON readings
  FOR ALL USING (vehicle_id IN (SELECT vehicle_id FROM vehicles WHERE user_id = auth.uid()));

-- Enable RLS on predictions
ALTER TABLE predictions ENABLE ROW LEVEL SECURITY;
CREATE POLICY predictions_owner_only ON predictions
  FOR ALL USING (vehicle_id IN (SELECT vehicle_id FROM vehicles WHERE user_id = auth.uid()));

-- Enable RLS on alerts
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
CREATE POLICY alerts_owner_only ON alerts
  FOR ALL USING (vehicle_id IN (SELECT vehicle_id FROM vehicles WHERE user_id = auth.uid()));

-- Enable RLS on trips
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
CREATE POLICY trips_owner_only ON trips
  FOR ALL USING (vehicle_id IN (SELECT vehicle_id FROM vehicles WHERE user_id = auth.uid()));
