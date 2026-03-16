-- profiles table (extends auth.users with app-level access role)
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT '',
  role text NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'coach', 'admin')),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- persons table
-- Note: persons.role (athlete/coach) is different from profiles.role (user/coach/admin)
CREATE TABLE IF NOT EXISTS public.persons (
  id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  age int CHECK (age BETWEEN 1 AND 120),
  gender text CHECK (gender IN ('male', 'female', 'other')),
  weight numeric CHECK (weight BETWEEN 20 AND 300),
  height numeric CHECK (height BETWEEN 50 AND 250),
  max_heart_rate int CHECK (max_heart_rate BETWEEN 60 AND 220),
  resting_heart_rate int CHECK (resting_heart_rate BETWEEN 30 AND 100),
  role text NOT NULL DEFAULT 'athlete' CHECK (role IN ('athlete', 'coach')),
  sport_type text,
  fitness_level text CHECK (fitness_level IN ('beginner', 'intermediate', 'advanced', 'elite')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- auto-update updated_at on persons
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER persons_set_updated_at
  BEFORE UPDATE ON public.persons
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- training_sessions table
CREATE TABLE IF NOT EXISTS public.training_sessions (
  id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  person_id text NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  title text NOT NULL,
  start_time timestamptz NOT NULL,
  end_time timestamptz,
  duration int NOT NULL DEFAULT 0 CHECK (duration >= 0),
  distance numeric CHECK (distance >= 0),
  avg_heart_rate int CHECK (avg_heart_rate BETWEEN 30 AND 250),
  max_heart_rate int CHECK (max_heart_rate BETWEEN 30 AND 250),
  min_heart_rate int CHECK (min_heart_rate BETWEEN 30 AND 250),
  calories numeric CHECK (calories >= 0),
  training_type text NOT NULL DEFAULT 'general' CHECK (training_type IN ('running','cycling','gym','swimming','general','other')),
  heart_rate_data jsonb NOT NULL DEFAULT '[]',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS training_sessions_user_start ON public.training_sessions (user_id, start_time DESC);
CREATE INDEX IF NOT EXISTS training_sessions_person_start ON public.training_sessions (person_id, start_time DESC);

-- force_plate_sessions table
CREATE TABLE IF NOT EXISTS public.force_plate_sessions (
  id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  person_id text NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  title text NOT NULL,
  start_time timestamptz NOT NULL,
  end_time timestamptz,
  duration int NOT NULL DEFAULT 0 CHECK (duration >= 0),
  test_type text NOT NULL DEFAULT 'custom' CHECK (test_type IN ('jumping','balance','gait','custom')),
  avg_force numeric CHECK (avg_force >= 0),
  max_force numeric CHECK (max_force >= 0),
  min_force numeric CHECK (min_force >= 0),
  peak_impulse numeric CHECK (peak_impulse >= 0),
  samples jsonb NOT NULL DEFAULT '[]',
  notes text,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS force_plate_sessions_user_start ON public.force_plate_sessions (user_id, start_time DESC);
CREATE INDEX IF NOT EXISTS force_plate_sessions_person_start ON public.force_plate_sessions (person_id, start_time DESC);

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.persons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.force_plate_sessions ENABLE ROW LEVEL SECURITY;

-- RLS: profiles
CREATE POLICY "profiles_select_own" ON public.profiles FOR SELECT USING (id = auth.uid());
CREATE POLICY "profiles_insert_own" ON public.profiles FOR INSERT WITH CHECK (id = auth.uid());
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE USING (id = auth.uid());
CREATE POLICY "profiles_delete_own" ON public.profiles FOR DELETE USING (id = auth.uid());

-- RLS: persons
CREATE POLICY "persons_select_own" ON public.persons FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "persons_insert_own" ON public.persons FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "persons_update_own" ON public.persons FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "persons_delete_own" ON public.persons FOR DELETE USING (user_id = auth.uid());

-- RLS: training_sessions
CREATE POLICY "training_sessions_select_own" ON public.training_sessions FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "training_sessions_insert_own" ON public.training_sessions FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "training_sessions_update_own" ON public.training_sessions FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "training_sessions_delete_own" ON public.training_sessions FOR DELETE USING (user_id = auth.uid());

-- RLS: force_plate_sessions
CREATE POLICY "force_plate_sessions_select_own" ON public.force_plate_sessions FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "force_plate_sessions_insert_own" ON public.force_plate_sessions FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "force_plate_sessions_update_own" ON public.force_plate_sessions FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "force_plate_sessions_delete_own" ON public.force_plate_sessions FOR DELETE USING (user_id = auth.uid());

-- auto-create profile row when a user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.profiles (id, name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', ''),
    'user'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
