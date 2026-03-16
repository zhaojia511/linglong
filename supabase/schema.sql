-- Supabase schema for Linglong platform
-- Run this in Supabase SQL Editor

-- Persons table
create table if not exists persons (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  age int not null,
  gender text not null check (gender in ('male','female','other')),
  weight numeric not null,
  height numeric not null,
  max_heart_rate int,
  resting_heart_rate int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Training sessions table
create table if not exists training_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  person_id uuid not null references persons(id) on delete cascade,
  title text not null,
  training_type text not null,
  notes text,
  start_time timestamptz not null,
  end_time timestamptz,
  duration int,
  avg_heart_rate int,
  max_heart_rate int,
  min_heart_rate int,
  calories numeric,
  heart_rate_data jsonb default '[]'::jsonb,
  synced boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- RLS
alter table persons enable row level security;
alter table training_sessions enable row level security;

-- Persons policies
create policy if not exists persons_select_own on persons
  for select using (auth.uid() = user_id);
create policy if not exists persons_insert_own on persons
  for insert with check (auth.uid() = user_id);
create policy if not exists persons_update_own on persons
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy if not exists persons_delete_own on persons
  for delete using (auth.uid() = user_id);

-- Training session policies
create policy if not exists sessions_select_own on training_sessions
  for select using (auth.uid() = user_id);
create policy if not exists sessions_insert_own on training_sessions
  for insert with check (auth.uid() = user_id);
create policy if not exists sessions_update_own on training_sessions
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy if not exists sessions_delete_own on training_sessions
  for delete using (auth.uid() = user_id);
