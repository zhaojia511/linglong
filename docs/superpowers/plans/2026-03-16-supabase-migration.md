# Supabase Migration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate Linglong from Node.js + MongoDB to Supabase (PostgreSQL + Auth), removing the backend entirely and having web app + mobile app call Supabase directly.

**Architecture:** Supabase hosts all data (persons, training_sessions, force_plate_sessions) with RLS enforcing per-user access. The web app replaces axios API calls with supabase-js client calls. The mobile app replaces the custom HTTP client with supabase_flutter. All existing field names (camelCase) are preserved via a mapping layer in db.js.

**Tech Stack:** Supabase (PostgreSQL, Auth, RPC), React + supabase-js v2, Flutter + supabase_flutter

**Spec:** `docs/superpowers/specs/2026-03-16-supabase-migration-deployment-design.md`

**Supabase project:** `https://krbobzpwgzxhnqssgwoy.supabase.co`

---

## Key facts before starting

- All existing pages use **camelCase** field names (`trainingType`, `startTime`, `avgHeartRate`, `personId`, `heartRateData`)
- Supabase returns **snake_case** column names (`training_type`, `start_time`, etc.)
- `db.js` must transform snake_case → camelCase on read and camelCase → snake_case on write
- All pages wrap responses as `response.data.data` — `db.js` must return the inner data directly (no wrapping)
- `persons` table has an app-level `role` field (`athlete`/`coach`) — separate from `profiles.role` (`user`/`coach`/`admin`)
- `RecordingManagement.jsx` posts sessions via `api.post('/sessions', data)` with a pre-generated `id`
- `PersonsManagement.jsx` posts persons via `api.post('/persons', data)` with a pre-generated `id`

---

## File Structure

### New files
- `supabase/migrations/001_initial_schema.sql` — tables, RLS, indexes, triggers
- `supabase/migrations/002_stats_rpc.sql` — get_training_stats function
- `web_app/src/services/db.js` — Supabase DB helper replacing all backend API calls

### Modified files
- `web_app/src/services/api.js` — remove axios/backend calls, keep authService, add re-exports from db.js
- `web_app/src/pages/Sessions.jsx` — replace `sessionService` import path
- `web_app/src/pages/SessionDetail.jsx` — replace `sessionService` + `personService` import paths
- `web_app/src/pages/PersonsManagement.jsx` — replace `api.get/post('/persons')` with db.js calls
- `web_app/src/pages/HistoryAnalysis.jsx` — replace `api.get(...)` calls with db.js calls
- `web_app/src/pages/RecordingManagement.jsx` — replace `api.get/post('/sessions')` with db.js calls
- `web_app/src/pages/Dashboard.jsx` — update sessionService import
- `web_app/src/pages/hooks/useDashboardData.js` — update sessionService import
- `mobile_app/pubspec.yaml` — add supabase_flutter
- `mobile_app/lib/main.dart` — initialize Supabase
- `mobile_app/lib/services/` — replace HTTP client with Supabase queries

### Deleted files
- `backend/` — entire directory (last step)

---

## Chunk 1: Supabase Database Setup

### Task 1: Create and run schema migrations

**Files:**
- Create: `supabase/migrations/001_initial_schema.sql`
- Create: `supabase/migrations/002_stats_rpc.sql`

- [ ] **Step 1: Create `supabase/migrations/001_initial_schema.sql`**

```sql
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
```

- [ ] **Step 2: Create `supabase/migrations/002_stats_rpc.sql`**

```sql
CREATE OR REPLACE FUNCTION public.get_training_stats(
  p_start_date timestamptz DEFAULT NULL,
  p_end_date timestamptz DEFAULT NULL,
  p_person_id text DEFAULT NULL
)
RETURNS json
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT json_build_object(
    'totalSessions', COUNT(*),
    'totalDuration', COALESCE(SUM(duration), 0),
    'totalCalories', COALESCE(SUM(calories), 0),
    'avgHeartRate', ROUND(AVG(avg_heart_rate)),
    'maxHeartRate', MAX(max_heart_rate),
    'trainingTypes', (
      SELECT json_object_agg(training_type, cnt)
      FROM (
        SELECT training_type, COUNT(*) as cnt
        FROM public.training_sessions
        WHERE user_id = auth.uid()
          AND (p_start_date IS NULL OR start_time >= p_start_date)
          AND (p_end_date IS NULL OR start_time <= p_end_date)
          AND (p_person_id IS NULL OR person_id = p_person_id)
        GROUP BY training_type
      ) t
    )
  )
  FROM public.training_sessions
  WHERE user_id = auth.uid()
    AND (p_start_date IS NULL OR start_time >= p_start_date)
    AND (p_end_date IS NULL OR start_time <= p_end_date)
    AND (p_person_id IS NULL OR person_id = p_person_id);
$$;
```

- [ ] **Step 3: Run SQL in Supabase dashboard**

Go to: [https://supabase.com/dashboard/project/krbobzpwgzxhnqssgwoy/sql/new](https://supabase.com/dashboard/project/krbobzpwgzxhnqssgwoy/sql/new)

1. Paste and run `001_initial_schema.sql`
2. Paste and run `002_stats_rpc.sql`

Verify: Table Editor shows `profiles`, `persons`, `training_sessions`, `force_plate_sessions`.

- [ ] **Step 4: Commit migration files**

```bash
git add supabase/
git commit -m "feat: add Supabase schema migrations, RLS policies, and stats RPC"
```

---

## Chunk 2: Web App Migration

### Task 2: Create db.js with camelCase mapping layer

**Files:**
- Create: `web_app/src/services/db.js`

The key design principle: Supabase stores snake_case columns, but all pages expect camelCase. `db.js` maps between them so no page components need to change their field access patterns.

- [ ] **Step 1: Create `web_app/src/services/db.js`**

```js
import { supabase } from './supabaseClient'

// snake_case → camelCase for session objects returned from Supabase
function toSession(row) {
  if (!row) return null
  return {
    id: row.id,
    personId: row.person_id,
    title: row.title,
    trainingType: row.training_type,
    startTime: row.start_time,
    endTime: row.end_time,
    duration: row.duration,
    distance: row.distance,
    avgHeartRate: row.avg_heart_rate,
    maxHeartRate: row.max_heart_rate,
    minHeartRate: row.min_heart_rate,
    calories: row.calories,
    heartRateData: row.heart_rate_data ?? [],
    notes: row.notes,
    createdAt: row.created_at,
  }
}

// camelCase → snake_case for session objects sent to Supabase
function fromSession(session) {
  const row = {}
  if (session.id !== undefined) row.id = session.id
  if (session.personId !== undefined) row.person_id = session.personId
  if (session.title !== undefined) row.title = session.title
  if (session.trainingType !== undefined) row.training_type = session.trainingType
  if (session.startTime !== undefined) row.start_time = session.startTime
  if (session.endTime !== undefined) row.end_time = session.endTime
  if (session.duration !== undefined) row.duration = session.duration
  if (session.distance !== undefined) row.distance = session.distance
  if (session.avgHeartRate !== undefined) row.avg_heart_rate = session.avgHeartRate
  if (session.maxHeartRate !== undefined) row.max_heart_rate = session.maxHeartRate
  if (session.minHeartRate !== undefined) row.min_heart_rate = session.minHeartRate
  if (session.calories !== undefined) row.calories = session.calories
  if (session.heartRateData !== undefined) row.heart_rate_data = session.heartRateData
  if (session.notes !== undefined) row.notes = session.notes
  return row
}

// snake_case → camelCase for person objects
function toPerson(row) {
  if (!row) return null
  return {
    id: row.id,
    name: row.name,
    age: row.age,
    gender: row.gender,
    weight: row.weight,
    height: row.height,
    maxHeartRate: row.max_heart_rate,
    restingHeartRate: row.resting_heart_rate,
    role: row.role,
    sport_type: row.sport_type,
    fitness_level: row.fitness_level,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }
}

// camelCase → snake_case for person objects
function fromPerson(person) {
  const row = {}
  if (person.id !== undefined) row.id = person.id
  if (person.name !== undefined) row.name = person.name
  if (person.age !== undefined) row.age = person.age
  if (person.gender !== undefined) row.gender = person.gender
  if (person.weight !== undefined) row.weight = person.weight
  if (person.height !== undefined) row.height = person.height
  if (person.maxHeartRate !== undefined) row.max_heart_rate = person.maxHeartRate
  if (person.restingHeartRate !== undefined) row.resting_heart_rate = person.restingHeartRate
  if (person.role !== undefined) row.role = person.role
  if (person.sport_type !== undefined) row.sport_type = person.sport_type
  if (person.fitness_level !== undefined) row.fitness_level = person.fitness_level
  return row
}

// --- sessionService (matches existing export name in api.js) ---

export const sessionService = {
  async getSessions({ limit = 50, offset = 0, personId, startDate, endDate } = {}) {
    let query = supabase
      .from('training_sessions')
      .select('*')
      .order('start_time', { ascending: false })
      .range(offset, offset + limit - 1)
    if (personId) query = query.eq('person_id', personId)
    if (startDate) query = query.gte('start_time', startDate)
    if (endDate) query = query.lte('start_time', endDate)
    const { data, error } = await query
    if (error) throw error
    return { data: (data ?? []).map(toSession) }
  },

  async getSession(id) {
    const { data, error } = await supabase
      .from('training_sessions')
      .select('*')
      .eq('id', id)
      .single()
    if (error) throw error
    return { data: toSession(data) }
  },

  async getStats({ startDate, endDate, personId } = {}) {
    const { data, error } = await supabase.rpc('get_training_stats', {
      p_start_date: startDate || null,
      p_end_date: endDate || null,
      p_person_id: personId || null,
    })
    if (error) throw error
    return { data }
  },

  async deleteSession(id) {
    const { error } = await supabase
      .from('training_sessions')
      .delete()
      .eq('id', id)
    if (error) throw error
    return { data: { success: true } }
  },

  async upsertSession(session) {
    const { data: { user } } = await supabase.auth.getUser()
    const row = { ...fromSession(session), user_id: user.id }
    const { data, error } = await supabase
      .from('training_sessions')
      .upsert(row, { onConflict: 'id' })
      .select()
      .single()
    if (error) throw error
    return { data: toSession(data) }
  },
}

// --- personService (matches existing export name in api.js) ---

export const personService = {
  async getPersons({ role } = {}) {
    let query = supabase
      .from('persons')
      .select('*')
      .order('created_at', { ascending: false })
    if (role) query = query.eq('role', role)
    const { data, error } = await query
    if (error) throw error
    return { data: (data ?? []).map(toPerson) }
  },

  async getPerson(id) {
    const { data, error } = await supabase
      .from('persons')
      .select('*')
      .eq('id', id)
      .single()
    if (error) throw error
    return { data: toPerson(data) }
  },

  async upsertPerson(person) {
    const { data: { user } } = await supabase.auth.getUser()
    const row = { ...fromPerson(person), user_id: user.id }
    const { data, error } = await supabase
      .from('persons')
      .upsert(row, { onConflict: 'id' })
      .select()
      .single()
    if (error) throw error
    return { data: toPerson(data) }
  },

  async deletePerson(id) {
    const { error } = await supabase
      .from('persons')
      .delete()
      .eq('id', id)
    if (error) throw error
    return { data: { success: true } }
  },
}
```

- [ ] **Step 2: Commit db.js**

```bash
git add web_app/src/services/db.js
git commit -m "feat: add Supabase db.js service with camelCase mapping layer"
```

### Task 3: Update api.js and page components

**Files:**
- Modify: `web_app/src/services/api.js`
- Modify: `web_app/src/pages/Sessions.jsx`
- Modify: `web_app/src/pages/SessionDetail.jsx`
- Modify: `web_app/src/pages/PersonsManagement.jsx`
- Modify: `web_app/src/pages/HistoryAnalysis.jsx`
- Modify: `web_app/src/pages/RecordingManagement.jsx`
- Modify: `web_app/src/pages/Dashboard.jsx`
- Modify: `web_app/src/pages/hooks/useDashboardData.js`

- [ ] **Step 1: Replace `web_app/src/services/api.js`**

Remove the axios instance, request interceptor, and backend API calls. Keep only `authService`. Re-export `sessionService` and `personService` from `db.js`.

Replace the entire file with:

```js
import { supabase } from './supabaseClient'
export { sessionService, personService } from './db'

export const authService = {
  login: async (email, password) => {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
    return { user: data.user, session: data.session }
  },

  register: async (email, password, name) => {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { name } },
    })
    if (error) throw error
    return { user: data.user, session: data.session }
  },

  resetPassword: async (email) => {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`,
    })
    if (error) throw error
    return { message: 'Password reset email sent successfully' }
  },

  updatePassword: async (newPassword) => {
    const { data, error } = await supabase.auth.updateUser({ password: newPassword })
    if (error) throw error
    return data
  },

  logout: async () => {
    await supabase.auth.signOut()
  },

  getCurrentUser: async () => {
    const { data } = await supabase.auth.getUser()
    return data.user || null
  },

  isAuthenticated: async () => {
    const { data } = await supabase.auth.getSession()
    return !!data.session?.access_token
  },
}

export default {}
```

- [ ] **Step 2: Update `PersonsManagement.jsx`**

Read the file first, then:
- Replace `api.get('/persons', { params: { role: 'athlete' } })` with `personService.getPersons({ role: 'athlete' })`
- Replace `api.post('/persons', data)` with `personService.upsertPerson(data)`:
  - **New persons** (no `editingPerson`): generate a uuid — `personService.upsertPerson({ ...data, id: uuidv4() })`
    Check if `uuid` is in `web_app/package.json`; if not run `npm install uuid` and add `import { v4 as uuidv4 } from 'uuid'`
  - **Existing persons**: pass existing id — `personService.upsertPerson({ ...data, id: editingPerson.id })`
- Replace person delete (UI-only) with `await personService.deletePerson(id)` — now actually deletes from DB
- All response shapes stay the same: `response.data.data || []`
- Add import: `import { personService } from '../services/api'`
- Remove import of `api` default if it's no longer used

- [ ] **Step 3: Update `HistoryAnalysis.jsx`**

Read the file first, then:
- Replace `api.get('/sessions/stats/summary', { params })` with `sessionService.getStats(params)`
- Replace `api.get('/sessions?limit=100')` with `sessionService.getSessions({ limit: 100 })`
- Replace `api.get('/persons')` with `personService.getPersons()`
- **Stats response shape is different:** stats is accessed as `statsResponse.data` (not `.data.data`).
  Change `setStats(statsResponse.data.data)` → `setStats(statsResponse.data)`
- Sessions and persons keep the same shape: `response.data.data || []`
- Add import: `import { sessionService, personService } from '../services/api'`
- Remove import of `api` default

- [ ] **Step 4: Update `RecordingManagement.jsx`**

Read the file first, then:
- Replace `api.get('/sessions')` with `sessionService.getSessions()`
- Replace `api.get('/persons')` with `personService.getPersons()`
- Replace `api.post('/sessions', data)` with `sessionService.upsertSession(data)` — this now actually persists to Supabase
- Replace delete (UI-only) with `await sessionService.deleteSession(id)` — now actually deletes from DB
- All response shapes stay the same (`response.data.data || []`)
- Add import: `import { sessionService, personService } from '../services/api'`
- Remove import of `api` default

- [ ] **Step 5: Verify Sessions.jsx, SessionDetail.jsx, Dashboard.jsx, useDashboardData.js**

These already import `sessionService` and `personService` by name from `api.js`. Since `api.js` now re-exports them from `db.js`, no import changes needed. Verify by checking the import lines:

```bash
grep -n "from.*services/api" web_app/src/pages/Sessions.jsx web_app/src/pages/SessionDetail.jsx web_app/src/pages/Dashboard.jsx web_app/src/pages/hooks/useDashboardData.js
```

If all imports are named (`{ sessionService }` or `{ personService }`), no changes needed. If any use the default `api` import, update them.

- [ ] **Step 6: Remove axios**

```bash
grep -r "axios\|from.*api'" web_app/src --include="*.js" --include="*.jsx"
```

If no files import axios directly, uninstall:
```bash
cd web_app && npm uninstall axios
```

- [ ] **Step 7: Local smoke test**

```bash
cd web_app && npm run dev
```

Open http://localhost:5173 and:
1. Log in
2. Navigate to Sessions — verify list loads
3. Navigate to Persons — verify list loads
4. Navigate to Dashboard — verify stats load
5. Navigate to History Analysis — verify charts load
6. Check browser console for errors

- [ ] **Step 8: Build for production**

```bash
cd web_app && npm run build
```

Expected: success, no errors.

- [ ] **Step 9: Commit**

```bash
git add web_app/src/ web_app/package.json web_app/package-lock.json
git commit -m "feat: migrate web app from Node.js backend to Supabase direct calls"
```

---

## Chunk 3: Mobile App Migration

### Task 4: Add supabase_flutter and initialize

**Files:**
- Modify: `mobile_app/pubspec.yaml`
- Modify: `mobile_app/lib/main.dart`
- Create: `mobile_app/lib/services/supabase_service.dart`

- [ ] **Step 1: Add supabase_flutter**

```bash
cd mobile_app && flutter pub add supabase_flutter
```

- [ ] **Step 2: Create `mobile_app/lib/services/supabase_service.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://krbobzpwgzxhnqssgwoy.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtyYm9ienB3Z3p4aG5xc3Nnd295Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcyNDM1OTEsImV4cCI6MjA4MjgxOTU5MX0.4z4gEpUdVahjHfmSCiyTEaPS_vWljX9zzjKSi_Gm99E',
  );

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}
```

- [ ] **Step 3: Read current `main.dart` and add Supabase initialization**

```bash
cat mobile_app/lib/main.dart
```

Add before `runApp`:
```dart
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const MyApp());
}
```

- [ ] **Step 4: Commit**

```bash
git add mobile_app/pubspec.yaml mobile_app/pubspec.lock mobile_app/lib/main.dart mobile_app/lib/services/supabase_service.dart
git commit -m "feat: add supabase_flutter initialization to mobile app"
```

### Task 5: Replace mobile auth with Supabase

**Files:**
- Find and modify existing auth service

- [ ] **Step 1: Find existing auth files**

```bash
find mobile_app/lib -name "*.dart" | xargs grep -l "token\|login\|auth\|jwt" 2>/dev/null
```

Read each file found.

- [ ] **Step 2: Replace auth logic**

Create or replace auth service with:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  static SupabaseClient get _client => SupabaseService.client;

  static Session? get currentSession => _client.auth.currentSession;
  static User? get currentUser => _client.auth.currentUser;
  static bool get isAuthenticated => currentSession != null;

  static Future<AuthResponse> login(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> register(
      String email, String password, String name) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
  }

  static Future<void> logout() async {
    await _client.auth.signOut();
  }

  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;
}
```

- [ ] **Step 3: Remove flutter_secure_storage JWT usage**

Find all files that read/write JWT tokens to secure storage and remove that code:
```bash
grep -r "secure_storage\|jwt\|accessToken\|access_token" mobile_app/lib --include="*.dart" -l
```

Replace with `AuthService.currentSession?.accessToken` where the token value is needed.

- [ ] **Step 4: Commit**

```bash
git add mobile_app/lib/
git commit -m "feat: replace custom JWT auth with Supabase auth in mobile app"
```

### Task 6: Replace mobile API calls with Supabase queries

**Files:**
- Find and modify existing API/data service files

- [ ] **Step 1: Find existing API service files**

```bash
find mobile_app/lib/services -name "*.dart" 2>/dev/null || find mobile_app/lib -name "*service*" -o -name "*api*" -o -name "*repository*" | grep "\.dart$"
```

Read each file.

- [ ] **Step 2: Create persons service**

```dart
import 'supabase_service.dart';

class PersonsService {
  static get _client => SupabaseService.client;

  static Future<List<Map<String, dynamic>>> getAll({String? role}) async {
    var query = _client
        .from('persons')
        .select()
        .order('created_at', ascending: false);
    if (role != null) query = query.eq('role', role);
    final data = await query;
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<Map<String, dynamic>> upsert(
      Map<String, dynamic> person) async {
    final user = _client.auth.currentUser!;
    final data = await _client
        .from('persons')
        .upsert({...person, 'user_id': user.id})
        .select()
        .single();
    return data;
  }

  static Future<void> delete(String id) async {
    await _client.from('persons').delete().eq('id', id);
  }
}
```

- [ ] **Step 3: Create sessions service**

```dart
import 'supabase_service.dart';

class SessionsService {
  static get _client => SupabaseService.client;

  static Future<List<Map<String, dynamic>>> getAll({
    String? personId,
    int limit = 50,
    int offset = 0,
    String? startDate,
    String? endDate,
  }) async {
    var query = _client
        .from('training_sessions')
        .select()
        .order('start_time', ascending: false)
        .range(offset, offset + limit - 1);
    if (personId != null) query = query.eq('person_id', personId);
    if (startDate != null) query = query.gte('start_time', startDate);
    if (endDate != null) query = query.lte('start_time', endDate);
    final data = await query;
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<Map<String, dynamic>> upsert(
      Map<String, dynamic> session) async {
    final user = _client.auth.currentUser!;
    final data = await _client
        .from('training_sessions')
        .upsert({...session, 'user_id': user.id})
        .select()
        .single();
    return data;
  }

  static Future<void> delete(String id) async {
    await _client.from('training_sessions').delete().eq('id', id);
  }
}
```

- [ ] **Step 4: Update all screens using old HTTP calls**

```bash
grep -rn "http\|dio\|HttpClient\|http.get\|http.post" mobile_app/lib --include="*.dart" -l
```

For each file, replace HTTP calls with the appropriate `PersonsService` or `SessionsService` call.

**Key field name note:** Supabase returns snake_case. The mobile app likely already used snake_case from the backend (check existing code). If the app used camelCase, add a mapping helper similar to the web app's `toSession`/`fromSession` functions.

- [ ] **Step 5: Run Flutter analyze**

```bash
cd mobile_app && flutter analyze
```

Fix all errors before proceeding.

- [ ] **Step 6: Commit**

```bash
git add mobile_app/lib/
git commit -m "feat: replace HTTP API calls with Supabase queries in mobile app"
```

---

## Chunk 4: Cleanup & Verification

### Task 7: Final verification and backend removal

- [ ] **Step 1: Verify web app build succeeds**

```bash
cd web_app && npm run build
```

Expected: success, `dist/` created.

- [ ] **Step 2: Verify mobile app compiles**

```bash
cd mobile_app && flutter build apk --debug
```

Expected: success.

- [ ] **Step 3: Update Supabase Auth settings**

In Supabase dashboard → Authentication → URL Configuration:
- Site URL: `https://linglong-test.pages.dev`
- Add to Redirect URLs: `https://linglong-test.pages.dev/reset-password`

- [ ] **Step 4: Remove backend directory**

```bash
rm -rf backend/
```

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: remove Node.js backend — fully migrated to Supabase"
```

---

## Supabase Dashboard Verification Checklist

After all tasks are complete:

- [ ] Table Editor: all 4 tables exist with correct columns
- [ ] Authentication → Users: existing test users present
- [ ] SQL Editor: `SELECT * FROM persons LIMIT 1` returns empty (not error) when logged in as test user
- [ ] RPC: `SELECT get_training_stats()` returns JSON with zero counts (not error)
- [ ] Auth → URL Configuration: redirect URLs include production domain
