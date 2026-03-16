-- Create tables first
CREATE TABLE IF NOT EXISTS public.persons (
  id text primary key,
  user_id text not null,
  name text,
  age int,
  gender text,
  weight numeric,
  height numeric,
  max_heart_rate int,
  resting_heart_rate int,
  created_at timestamptz not null default now(),
  updated_at timestamptz default now()
);

CREATE TABLE IF NOT EXISTS public.training_sessions (
  id text primary key,
  user_id text not null,
  person_id text,
  title text default 'Training Session',
  training_type text,
  notes text,
  start_time timestamptz,
  end_time timestamptz,
  duration int,
  avg_heart_rate int,
  max_heart_rate int,
  min_heart_rate int,
  calories numeric,
  heart_rate_data jsonb default '[]'::jsonb,
  synced boolean default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz default now()
);

CREATE INDEX IF NOT EXISTS persons_user_id_idx ON public.persons (user_id);
CREATE INDEX IF NOT EXISTS training_sessions_user_id_idx ON public.training_sessions (user_id);
CREATE INDEX IF NOT EXISTS training_sessions_person_id_idx ON public.training_sessions (person_id);
CREATE INDEX IF NOT EXISTS training_sessions_start_time_idx ON public.training_sessions (start_time desc);

-- Enable RLS
ALTER TABLE public.persons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_sessions ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY persons_select_own ON public.persons FOR SELECT USING (auth.uid()::text = user_id);
CREATE POLICY persons_insert_own ON public.persons FOR INSERT WITH CHECK (auth.uid()::text = user_id);
CREATE POLICY persons_update_own ON public.persons FOR UPDATE USING (auth.uid()::text = user_id);
CREATE POLICY persons_delete_own ON public.persons FOR DELETE USING (auth.uid()::text = user_id);

CREATE POLICY sessions_select_own ON public.training_sessions FOR SELECT USING (auth.uid()::text = user_id);
CREATE POLICY sessions_insert_own ON public.training_sessions FOR INSERT WITH CHECK (auth.uid()::text = user_id);
CREATE POLICY sessions_update_own ON public.training_sessions FOR UPDATE USING (auth.uid()::text = user_id);
CREATE POLICY sessions_delete_own ON public.training_sessions FOR DELETE USING (auth.uid()::text = user_id);
