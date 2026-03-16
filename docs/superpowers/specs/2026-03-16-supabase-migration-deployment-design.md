# Supabase Migration & Aliyun Deployment Design

**Date:** 2026-03-16
**Status:** Approved

---

## Overview

Migrate the Linglong HR monitoring system from a Node.js + MongoDB backend to a serverless architecture using Supabase (PostgreSQL + Auth). Web app and mobile app call Supabase directly. The Node.js backend is eliminated entirely. The web app is deployed as static files on Aliyun ECS (Nginx) alongside the existing WordPress site.

---

## Architecture

### Current

```
Web App (React)    Mobile App (Flutter)
       ↓                    ↓
  Node.js Backend (Express, port 3000)
       ↓
  MongoDB (localhost:27017)
```

### Target

```
Web App (React)    Mobile App (Flutter)
       ↓                    ↓
  Supabase (Auth + PostgreSQL + RLS)

Aliyun ECS (CentOS 7.9):
  Nginx
  ├── port 80/443 → WordPress (existing, unchanged)
  └── port 80/443 → React static build (new subdomain, e.g. app.yourdomain.com)
```

No Node.js process. No MongoDB. No custom JWT.

---

## Supabase Database Schema

### Table: `profiles`
Extends `auth.users` with app-specific user fields.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | uuid | PK, FK → auth.users.id | |
| name | text | not null | |
| role | text | not null, default 'user' | enum: user/coach/admin |
| created_at | timestamptz | default now() | |

### Table: `persons`
| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | text | PK | App-generated string ID (from mobile) |
| user_id | uuid | not null, FK → auth.users.id | |
| name | text | not null | |
| age | int | not null, check 1-120 | |
| gender | text | not null | enum: male/female/other |
| weight | numeric | not null, check 20-300 | |
| height | numeric | not null, check 50-250 | |
| max_heart_rate | int | check 60-220 | optional |
| resting_heart_rate | int | check 30-100 | optional |
| created_at | timestamptz | default now() | |
| updated_at | timestamptz | default now() | |

### Table: `training_sessions`
| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | text | PK | App-generated string ID |
| user_id | uuid | not null, FK → auth.users.id | |
| person_id | text | not null, FK → persons.id | |
| title | text | not null | |
| start_time | timestamptz | not null | |
| end_time | timestamptz | | |
| duration | int | not null, check >= 0 | seconds |
| distance | numeric | check >= 0 | |
| avg_heart_rate | int | check 30-250 | |
| max_heart_rate | int | check 30-250 | |
| min_heart_rate | int | check 30-250 | |
| calories | numeric | check >= 0 | |
| training_type | text | not null | enum: running/cycling/gym/swimming/general/other |
| heart_rate_data | jsonb | default '[]' | array of {timestamp, heartRate, deviceId} |
| notes | text | | |
| created_at | timestamptz | default now() | |

**Index:** `(user_id, start_time DESC)`, `(person_id, start_time DESC)`

**Note on `heart_rate_data`:** Stored as jsonb array. For very long sessions this column can grow large but remains well within PostgreSQL's row size limits for typical training sessions (1-2 hours at 1Hz = ~3600 samples ≈ ~200KB).

### Table: `force_plate_sessions`
| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | text | PK | App-generated string ID |
| user_id | uuid | not null, FK → auth.users.id | |
| person_id | text | not null, FK → persons.id | |
| title | text | not null | |
| start_time | timestamptz | not null | |
| end_time | timestamptz | | |
| duration | int | not null, check >= 0 | |
| test_type | text | not null | enum: jumping/balance/gait/custom |
| avg_force | numeric | check >= 0 | |
| max_force | numeric | check >= 0 | |
| min_force | numeric | check >= 0 | |
| peak_impulse | numeric | check >= 0 | |
| samples | jsonb | default '[]' | array of {timestamp, channel1, channel2, channel3, channel4, deviceId} |
| notes | text | | |
| metadata | jsonb | | freeform additional data |
| created_at | timestamptz | default now() | |

---

## Row Level Security (RLS)

All four tables (`profiles`, `persons`, `training_sessions`, `force_plate_sessions`) have RLS enabled. Each table gets the same four policies:

```sql
-- SELECT: only own rows
CREATE POLICY "select_own" ON table_name
  FOR SELECT USING (user_id = auth.uid());

-- INSERT: user_id must equal caller (WITH CHECK prevents spoofing)
CREATE POLICY "insert_own" ON table_name
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- UPDATE: only own rows
CREATE POLICY "update_own" ON table_name
  FOR UPDATE USING (user_id = auth.uid());

-- DELETE: only own rows
CREATE POLICY "delete_own" ON table_name
  FOR DELETE USING (user_id = auth.uid());
```

`user_id NOT NULL` constraint is enforced at the column level to prevent NULL bypass.

**Coach/admin role:** Out of scope for this migration. The `role` field is preserved in `profiles` for future implementation. Currently all users are treated as `user` role.

**Data migration:** This is a fresh deployment with no existing production data in MongoDB. No data migration script is needed. If data exists, it must be exported manually before removing the backend.

---

## Stats Aggregation (replaces `/api/sessions/stats/summary`)

The backend's stats endpoint is reproduced as a **Supabase PostgreSQL function (RPC)**:

```sql
CREATE OR REPLACE FUNCTION get_training_stats(
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
      FROM (SELECT training_type, COUNT(*) as cnt FROM training_sessions
            WHERE user_id = auth.uid()
            AND (p_start_date IS NULL OR start_time >= p_start_date)
            AND (p_end_date IS NULL OR start_time <= p_end_date)
            AND (p_person_id IS NULL OR person_id = p_person_id)
            GROUP BY training_type) t
    )
  )
  FROM training_sessions
  WHERE user_id = auth.uid()
  AND (p_start_date IS NULL OR start_time >= p_start_date)
  AND (p_end_date IS NULL OR start_time <= p_end_date)
  AND (p_person_id IS NULL OR person_id = p_person_id);
$$;
```

Called from the client: `supabase.rpc('get_training_stats', { p_start_date, p_end_date, p_person_id })`

---

## Upsert / Sync Pattern

The mobile app uses an upsert pattern (POST creates or updates by `id`). In Supabase:

```js
await supabase.from('training_sessions').upsert(sessionData, { onConflict: 'id' })
```

The `id` column (PK, text) is the unique conflict target. This works because the mobile app generates the `id` before syncing.

---

## Web App Migration

### Changes
- Remove `axios` and the custom API client backend calls in `src/services/api.js`
- Replace all `api.*` calls with `supabase.from('table')` queries
- Replace stats call with `supabase.rpc('get_training_stats', ...)`
- Auth is already Supabase — no changes to Login, Register, logout
- Update `resetPassword` redirect URL from hardcoded `linglong-test.pages.dev` to the new production domain
- Update Supabase dashboard → Auth → URL Configuration to add new domain to allowed redirect URLs

### Environment Variables (`.env.production`)
```
VITE_SUPABASE_URL=https://xxx.supabase.co
VITE_SUPABASE_ANON_KEY=xxx
```
These are baked into the build at `npm run build` time — must be set before building.

---

## Mobile App Migration

### Changes
- Add `supabase_flutter` to `pubspec.yaml`
- Store Supabase credentials via `--dart-define=SUPABASE_URL=xxx --dart-define=SUPABASE_ANON_KEY=xxx` at build time (not hardcoded)
- Remove custom HTTP client and JWT token storage from `flutter_secure_storage`
- Replace all API calls with Supabase client queries
- Auth: `supabase.auth.signInWithPassword(email, password)`
- Upsert sessions: `supabase.from('training_sessions').upsert(..., onConflict: 'id')`

---

## Aliyun ECS Deployment

**Server:** CentOS 7.9, 1.7G RAM, 40G disk, Nginx running, WordPress on port 80/443.

### Step 1 — Add Swap (persistent)
```bash
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
```

### Step 2 — Open firewall port 443
```bash
firewall-cmd --permanent --add-service=https
firewall-cmd --reload
```

### Step 3 — Build web app locally
```bash
cd web_app
cp .env.example .env.production   # fill in Supabase values
npm run build
# output: web_app/dist/
```

### Step 4 — Upload to ECS
```bash
scp -r dist/ root@<ECS-IP>:/usr/share/nginx/html/linglong
```

### Step 5 — Add Nginx server block
Create `/etc/nginx/conf.d/linglong.conf`:
```nginx
server {
    listen 80;
    server_name app.yourdomain.com;
    root /usr/share/nginx/html/linglong;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

Test and reload:
```bash
nginx -t && systemctl reload nginx
```

### Step 6 — SSL via certbot
CentOS 7.9 is EOL (June 2024). Do NOT use the system certbot package — use pip:
```bash
yum install python3 python3-pip augeas-libs -y
pip3 install certbot certbot-nginx
certbot --nginx -d app.yourdomain.com
```
Certbot will inject the HTTPS block and add an HTTP→HTTPS redirect automatically.

### Step 7 — Verify
```bash
nginx -t && systemctl reload nginx
curl -I https://app.yourdomain.com
```

### No Node.js, no PM2, no MongoDB needed on ECS.

---

## Supabase Dashboard Configuration

- Auth → URL Configuration: add `https://app.yourdomain.com` to allowed redirect URLs
- Auth → URL Configuration: update Site URL to `https://app.yourdomain.com`

---

## Migration Order

1. Create Supabase tables + RLS policies + `get_training_stats` RPC function
2. Migrate web app (replace API calls, update redirect URL)
3. Test web app locally against Supabase
4. Deploy web app to ECS (steps 1-7 above)
5. Smoke test web app on production URL
6. Migrate mobile app (add supabase_flutter, replace auth + API calls)
7. Test mobile app end-to-end
8. Remove `backend/` directory from repo

---

## What Gets Removed

- `backend/` directory (entire Node.js server)
- `web_app/src/services/api.js` — replaced by direct Supabase calls
- MongoDB dependency
- Custom JWT auth logic
- `axios` dependency from web app
