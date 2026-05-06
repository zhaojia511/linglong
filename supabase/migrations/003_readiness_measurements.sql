-- Readiness measurements table
-- Stores dedicated resting HRV measurements taken outside of training sessions.
-- Each row represents one measurement per athlete per day.

CREATE TABLE IF NOT EXISTS public.readiness_measurements (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  person_id     text NOT NULL,            -- athlete ID (local Hive UUID)
  device_id     text NOT NULL,            -- BLE sensor ID
  measured_at   timestamptz NOT NULL DEFAULT now(),
  duration_sec  int NOT NULL,             -- measurement duration (60/120/180)

  -- Raw data
  rr_intervals  jsonb NOT NULL,           -- array of RR intervals in ms

  -- HRV metrics
  rmssd         double precision,         -- ms (primary vagal metric)
  sdnn          double precision,         -- ms (overall HRV)
  pnn50         double precision,         -- % (vagal tone)
  mean_rr       double precision,         -- ms
  sd1           double precision,         -- Poincaré short-term variability
  sd2           double precision,         -- Poincaré long-term variability

  -- Derived scores
  resting_hr    int,                      -- bpm at time of measurement
  quality_pct   double precision,         -- 0–100, based on valid interval count
  readiness_pct double precision,         -- 0–150, % of personal baseline RMSSD
  feeling       smallint                  -- 1 (very bad) – 5 (very good), nullable
    CHECK (feeling BETWEEN 1 AND 5),

  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Row-level security: users only see their own measurements
ALTER TABLE public.readiness_measurements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own readiness measurements"
  ON public.readiness_measurements FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own readiness measurements"
  ON public.readiness_measurements FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own readiness measurements"
  ON public.readiness_measurements FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own readiness measurements"
  ON public.readiness_measurements FOR DELETE
  USING (auth.uid() = user_id);

-- Index for fast per-athlete queries
CREATE INDEX IF NOT EXISTS idx_readiness_person_date
  ON public.readiness_measurements (user_id, person_id, measured_at DESC);
