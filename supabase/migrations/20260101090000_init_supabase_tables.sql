-- Creates initial Supabase tables for Linglong HR dashboard.

create table if not exists public.persons (
  id text primary key,
  user_id text not null,
  name text,
  age int,
  gender text,
  created_at timestamptz not null default now()
);

create index if not exists persons_user_id_idx on public.persons (user_id);

create table if not exists public.training_sessions (
  id text primary key,
  user_id text not null,
  person_id text,
  start_time timestamptz,
  duration int,
  calories numeric,
  avg_heart_rate int,
  max_heart_rate int,
  training_type text,
  created_at timestamptz not null default now()
);

create index if not exists training_sessions_user_id_idx on public.training_sessions (user_id);
create index if not exists training_sessions_person_id_idx on public.training_sessions (person_id);
create index if not exists training_sessions_start_time_idx on public.training_sessions (start_time desc);
