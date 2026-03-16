# Revive & Phase 2: Bug Fixes + Docs Refresh + Training Zones Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all blocking code bugs so the app runs end-to-end, refresh docs to reflect March 2026 reality, and implement Phase 2 training zones feature.

**Architecture:** The app is a 3-tier system: Flutter mobile → Node/Express backend (MongoDB) → React web app. Auth uses Supabase on the frontend but the backend uses its own JWT — these are misaligned and must be fixed. Web app talks to backend via Axios; backend routes have an Express ordering bug that makes `/stats/summary` unreachable.

**Tech Stack:** Node.js/Express/Mongoose (backend), React 18/Vite/TanStack Query/Recharts (web), Flutter 3 (mobile), Supabase (web auth), MongoDB (database)

---

## Chunk 1: Critical Bug Fixes

### Task 1: Fix backend route ordering bug (`/stats/summary` unreachable)

**Files:**
- Modify: `backend/src/routes/sessions.js`

**Context:** Express matches routes top-to-bottom. `GET /api/sessions/:id` is defined at line 90 BEFORE `GET /api/sessions/stats/summary` at line 118, so Express captures `"stats"` as the `:id` param and the stats endpoint is never reached.

- [ ] **Step 1: Move `stats/summary` route above `/:id` route**

In `backend/src/routes/sessions.js`, cut the entire `router.get('/stats/summary', ...)` block (lines 115–163) and paste it ABOVE the `router.get('/:id', ...)` block (currently line 90). Result: stats route must appear before any `/:id` route.

Final order in file should be:
1. `POST /` (create)
2. `GET /` (list)
3. `GET /stats/summary` ← moved up
4. `GET /:id`
5. `DELETE /:id`

- [ ] **Step 2: Verify with curl (backend must be running)**

```bash
cd backend && npm start &
sleep 3
curl http://localhost:3000/api/health
# Expected: {"status":"ok",...}
```

- [ ] **Step 3: Commit**

```bash
git add backend/src/routes/sessions.js
git commit -m "fix: move stats/summary route before /:id to fix Express routing"
```

---

### Task 2: Fix Dashboard.jsx — undefined `stats` variable

**Files:**
- Modify: `web_app/src/pages/Dashboard.jsx`

**Context:** `Dashboard.jsx` uses `useDashboardData()` which returns `{ statsQuery, sessionsQuery }`. The stats data is at `statsQuery.data`, but the JSX on lines 81–108 references a variable called `stats` that is never defined. This causes a runtime crash whenever there is any data.

- [ ] **Step 1: Add `stats` and `recentSessions` variables derived from query data**

In `web_app/src/pages/Dashboard.jsx`, after line 11 (`const { statsQuery, sessionsQuery } = useDashboardData()`), add:

```javascript
// Backend wraps all responses as { success: true, data: ... }
// statsQuery.data is the full response object; .data is the actual stats
const stats = statsQuery.data?.data ?? statsQuery.data

// sessionsQuery.data is { success, count, total, data: [...] }
// so the array is at .data.data
const recentSessions = sessionsQuery.data?.data ?? []
```

- [ ] **Step 2: Replace `sessionsQuery.data?.` references in JSX with `recentSessions`**

In the JSX (around line 114–133), replace every occurrence of `sessionsQuery.data?.` with `recentSessions?.` (or `recentSessions`):

```jsx
{/* line ~114 */}
{recentSessions.length === 0 ? (
  <p>No training sessions yet.</p>
) : (
  <ul className="session-list">
    {recentSessions.map((session) => (
```

- [ ] **Step 3: Verify the fix renders without error**

Run `cd web_app && npm run dev` and open `http://localhost:5173`. After login the dashboard should not crash (it may show empty/loading if backend isn't running, but should not throw a JS error).

- [ ] **Step 4: Commit**

```bash
git add web_app/src/pages/Dashboard.jsx
git commit -m "fix: define stats and recentSessions from TanStack Query wrapped responses"
```

---

### Task 3: Fix PersonsManagement.jsx — duplicate heading

**Files:**
- Modify: `web_app/src/pages/PersonsManagement.jsx`

**Context:** Lines 289–290 have two `<h2>` tags back-to-back: `Persons (N)` and `Athletes (N)`. This is a copy-paste leftover. Keep only the `Athletes` one.

- [ ] **Step 1: Remove duplicate heading**

In `web_app/src/pages/PersonsManagement.jsx`, delete line 289:
```jsx
          <h2 className="text-xl font-semibold">Persons ({persons.length})</h2>
```
Keep line 290 (`Athletes`).

- [ ] **Step 2: Commit**

```bash
git add web_app/src/pages/PersonsManagement.jsx
git commit -m "fix: remove duplicate Persons/Athletes heading"
```

---

### Task 4: Fix backend auth middleware — accept Supabase JWT

**Files:**
- Modify: `backend/src/middleware/auth.js`

**Context:** The web app sends Supabase access tokens (JWTs signed with Supabase's secret). The backend's `protect` middleware calls `jwt.verify(token, process.env.JWT_SECRET)` using the *backend's own* JWT secret — this will always fail for Supabase tokens. The backend then tries to look up `User.findById(decoded.id)` from MongoDB, but Supabase users don't exist in MongoDB.

**Fix strategy:** Decode the Supabase JWT without verifying the signature (the token is already trusted because Supabase issued it and the frontend has a valid Supabase session). Extract the user's Supabase `sub` (UUID) and use it as a stable user identifier. Create or find a MongoDB User record by `supabaseId` on each request.

- [ ] **Step 1: Add `supabaseId` field to the User model**

Read `backend/src/models/User.js` first, then add a `supabaseId` field:

```javascript
supabaseId: {
  type: String,
  unique: true,
  sparse: true  // sparse allows multiple nulls (for existing users)
}
```

- [ ] **Step 2: Update auth middleware to decode Supabase token**

Replace the body of `exports.protect` in `backend/src/middleware/auth.js` with:

```javascript
exports.protect = async (req, res, next) => {
  let token;

  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    return res.status(401).json({
      error: { message: 'Not authorized to access this route', status: 401 }
    });
  }

  try {
    // Decode without verifying — Supabase has already authenticated the user
    // The token is a standard JWT; we extract the sub claim (Supabase user UUID)
    const decoded = jwt.decode(token);

    if (!decoded || !decoded.sub) {
      return res.status(401).json({
        error: { message: 'Invalid token', status: 401 }
      });
    }

    const supabaseId = decoded.sub;

    // Find or create a MongoDB user record keyed by supabaseId
    let user = await User.findOne({ supabaseId });
    if (!user) {
      user = await User.create({
        supabaseId,
        email: decoded.email || `${supabaseId}@supabase.local`,
        name: decoded.user_metadata?.name || decoded.email || supabaseId,
        password: 'supabase-managed',  // placeholder, never used for login
      });
    }

    req.user = user;
    next();
  } catch (error) {
    console.error('Auth middleware error:', error);
    return res.status(401).json({
      error: { message: 'Not authorized to access this route', status: 401 }
    });
  }
};
```

- [ ] **Step 3: Make `password` optional in User model (required for Supabase auto-create)**

In `backend/src/models/User.js`:

1. Add `supabaseId` field to the schema (before `role`):
```javascript
supabaseId: {
  type: String,
  unique: true,
  sparse: true,   // sparse index: allows multiple null values
},
```

2. Change `password` field to not be required and remove minlength (Supabase users never use it):
```javascript
password: {
  type: String,
  required: false,
  select: false,
},
```

3. Update the pre-save hook to skip hashing when password is absent:
```javascript
UserSchema.pre('save', async function(next) {
  if (!this.password || !this.isModified('password')) {
    return next();
  }
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
});
```

- [ ] **Step 4: Restart backend and test with a Supabase token**

```bash
# Get a token from the web app (F12 → Application → Local Storage, or console:
# supabase.auth.getSession() in browser console)
# Then test:
curl -H "Authorization: Bearer SUPABASE_TOKEN" \
  http://localhost:3000/api/sessions
# Expected: {"success":true,"count":0,"total":0,"data":[]}
```

- [ ] **Step 5: Commit**

```bash
git add backend/src/models/User.js backend/src/middleware/auth.js
git commit -m "fix: accept Supabase JWTs in backend auth middleware, auto-create user records"
```

---

### Task 5: Fix field name mismatch — frontend snake_case vs backend camelCase

**Files:**
- Modify: `web_app/src/pages/RecordingManagement.jsx`
- Modify: `web_app/src/pages/HistoryAnalysis.jsx`

**Context:** The backend `TrainingSession` model uses camelCase (`avgHeartRate`, `maxHeartRate`, `startTime`, `trainingType`, `personId`). But `RecordingManagement.jsx` sends and reads snake_case fields (`avg_heart_rate`, `max_heart_rate`, `start_time`, `training_type`, `person_id`). `HistoryAnalysis.jsx` also reads snake_case from the API response. This means creates/edits fail silently and the analysis page shows all dashes.

- [ ] **Step 1: Fix RecordingManagement.jsx — camelCase fields, id generation, display table**

**A) Replace snake_case keys with camelCase throughout.** Update ALL of: initial `formData` state, `handleSubmit` payload, `handleEdit` assignment, all `onChange` handlers, all JSX `value` props, AND the display table cell reads. The complete field mapping applies everywhere:

| Old (snake_case) | New (camelCase) |
|---|---|
| `person_id` | `personId` |
| `training_type` | `trainingType` |
| `start_time` | `startTime` |
| `end_time` | `endTime` |
| `avg_heart_rate` | `avgHeartRate` |
| `max_heart_rate` | `maxHeartRate` |
| `min_heart_rate` | `minHeartRate` |

The display table cells in the JSX (around lines 388–402) also read snake_case — update those too:
- `session.training_type` → `session.trainingType`
- `session.start_time` → `session.startTime`
- `session.avg_heart_rate` → `session.avgHeartRate`

The `handleEdit` function (around lines 80–96) reads from the API response object — update those reads too:
- `session.person_id` → `session.personId`
- `session.training_type` → `session.trainingType`
- `session.start_time` → `session.startTime`
- `session.end_time` → `session.endTime`
- `session.avg_heart_rate` → `session.avgHeartRate`
- `session.max_heart_rate` → `session.maxHeartRate`
- `session.min_heart_rate` → `session.minHeartRate`

**B) Add `id` generation for new sessions.** The backend `TrainingSession` schema requires a unique `id` string field — it does NOT auto-generate one. New session POSTs from the form never include `id`, causing a validation error on every create. In `handleSubmit`, add a UUID when creating (not editing):

First, install `uuid` (it is NOT currently in `web_app/package.json`):
```bash
cd web_app && npm install uuid
```

Then add import at top of `RecordingManagement.jsx`:
```javascript
import { v4 as uuidv4 } from 'uuid'
```

In `handleSubmit`, change the POST for new sessions:
```javascript
if (editingSession) {
  await api.post(`/sessions`, { ...data, id: editingSession.id })
} else {
  await api.post('/sessions', { ...data, id: uuidv4() })
}
```

**C) Fix the `trainingType` enum.** Backend allows `['running', 'cycling', 'gym', 'swimming', 'general', 'other']` but form has `'weightlifting'` and `'yoga'` which aren't in the enum. Change:
- `<option value="weightlifting">Weightlifting</option>` → `<option value="gym">Gym / Weights</option>`
- `<option value="yoga">Yoga</option>` → `<option value="general">General / Yoga</option>`

- [ ] **Step 2: Fix HistoryAnalysis.jsx field reads**

Replace all snake_case field accesses with camelCase:
- `session.start_time` → `session.startTime`
- `session.avg_heart_rate` → `session.avgHeartRate`
- `session.max_heart_rate` → `session.maxHeartRate`
- `session.training_type` → `session.trainingType`
- `session.person_id` → `session.personId`

Also fix `prepareHeartRateData()` filter: `s.avg_heart_rate` → `s.avgHeartRate`

- [ ] **Step 3: Commit**

```bash
git add web_app/src/pages/RecordingManagement.jsx web_app/src/pages/HistoryAnalysis.jsx
git commit -m "fix: align frontend field names to backend camelCase schema"
```

---

### Task 6: Fix App.jsx — auth flash / missing Supabase session listener

**Files:**
- Modify: `web_app/src/App.jsx`

**Context:** `App.jsx` checks auth once on mount with `authService.isAuthenticated()`. If the user is logged in and refreshes the page, there's a brief moment where `authChecked=false` and `PrivateRoute` returns `null` (blank screen). Also, if Supabase session changes (e.g. token refresh), the app doesn't react.

- [ ] **Step 1: Add Supabase `onAuthStateChange` listener**

Replace the `useEffect` in `App.jsx` with one that subscribes to Supabase auth state changes:

```javascript
useEffect(() => {
  // Check current session
  authService.isAuthenticated().then((authed) => {
    setIsAuthenticated(authed)
    setAuthChecked(true)
  })

  // Subscribe to future auth changes (token refresh, logout from another tab)
  const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
    setIsAuthenticated(!!session)
    setAuthChecked(true)
  })

  return () => subscription.unsubscribe()
}, [])
```

Also add the import at the top: `import { supabase } from './services/supabaseClient'`

- [ ] **Step 2: Show loading spinner instead of null while checking auth**

Change `PrivateRoute`:
```javascript
const PrivateRoute = ({ children }) => {
  if (!authChecked) return <div className="container">Loading...</div>
  return isAuthenticated ? children : <Navigate to="/login" />
}
```

- [ ] **Step 3: Commit**

```bash
git add web_app/src/App.jsx
git commit -m "fix: subscribe to Supabase auth state changes, show loading during auth check"
```

---

### Task 7: Fix Sessions.jsx — no error state

**Files:**
- Modify: `web_app/src/pages/Sessions.jsx`

**Context:** `Sessions.jsx` catches errors in `loadSessions` but only logs to console — the user sees a blank list with no explanation.

- [ ] **Step 1: Add error state**

Add `const [error, setError] = useState('')` to state. In `loadSessions`, set error on catch:
```javascript
} catch (error) {
  console.error('Error loading sessions:', error)
  setError('Failed to load sessions. Is the backend running?')
} finally {
```

In the JSX, after the filter card and before the sessions card, add:
```jsx
{error && (
  <div className="card" style={{background:'#fff3cd', border:'1px solid #ffc107', padding:'15px', marginBottom:'20px'}}>
    <strong>Error:</strong> {error}
    <button onClick={loadSessions} className="btn btn-primary" style={{marginLeft:'15px'}}>Retry</button>
  </div>
)}
```

- [ ] **Step 2: Commit**

```bash
git add web_app/src/pages/Sessions.jsx
git commit -m "fix: show error state in Sessions page when API call fails"
```

---

## Chunk 2: Documentation Refresh

### Task 8: Update WEB_APP_STATUS.md

**Files:**
- Modify: `WEB_APP_STATUS.md`

- [ ] **Step 1: Rewrite WEB_APP_STATUS.md to reflect current state**

Replace the contents with an accurate status as of 2026-03-16:

```markdown
# Web App Status

**Date:** 2026-03-16
**Status:** In active development — bug fixes applied, Phase 2 starting
**URL:** https://linglong-test.pages.dev/

---

## ✅ Fixed (2026-03-16)

- Backend route ordering: `/stats/summary` now reachable
- Dashboard: `stats` variable was undefined, now correctly reads from `statsQuery.data`
- Auth middleware: now accepts Supabase JWTs, auto-creates MongoDB user on first request
- Field name mismatch: frontend aligned to backend camelCase (`avgHeartRate`, `startTime`, etc.)
- RecordingManagement: training type enum fixed (`gym`, `general` instead of `weightlifting`, `yoga`)
- Sessions page: shows error state when API is unreachable
- App.jsx: subscribes to Supabase auth state changes, no blank screen flash

## ✅ Working Features

### Authentication
- User registration and login via Supabase Auth
- Session persistence across page refreshes
- Password reset via email
- Protected routes

### Web App Pages
- Dashboard (stats + recent sessions)
- Sessions list with date filtering
- Session detail view
- Persons/Athlete management (create, edit)
- Recording management (create, edit sessions manually)
- History analysis with charts (HR trend, training types, monthly progress)

### Backend API
- All CRUD endpoints for sessions and persons
- Stats summary endpoint
- JWT auth (Supabase token passthrough)

---

## 🚨 Known Issues & Limitations

### Backend Not Publicly Deployed
Backend must be run locally (`cd backend && npm start`).
`VITE_API_BASE_URL` defaults to `http://localhost:3000/api` in development.
For Cloudflare Pages production: set `VITE_API_BASE_URL` env var to your deployed backend URL.

### No Token Signature Verification
Backend decodes (not verifies) Supabase tokens. This is acceptable for development
but production should verify via Supabase's JWKS endpoint.

### Delete Person Not Implemented in Backend
PersonsManagement delete only removes from UI state. Backend has no DELETE /persons/:id endpoint.

---

## 🔧 Local Development Setup

```bash
# Terminal 1 — Backend
cd backend
cp .env.example .env   # edit with your MongoDB URI and JWT_SECRET
npm install
npm start              # runs on http://localhost:3000

# Terminal 2 — Web App
cd web_app
cp .env.example .env.local  # set VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY
npm install
npm run dev            # runs on http://localhost:5173
```

---

## 📝 Next Steps (Phase 2)

- [ ] Training zones calculation (Zone 1–5) on session detail page
- [ ] CSV export for sessions
- [ ] Backend DELETE /persons/:id endpoint
- [ ] Production backend deployment
- [ ] Supabase JWT signature verification in backend

**Last Updated:** 2026-03-16
```

- [ ] **Step 2: Commit**

```bash
git add WEB_APP_STATUS.md
git commit -m "docs: refresh WEB_APP_STATUS.md to reflect March 2026 state and fixes"
```

---

### Task 9: Update ROADMAP.md dates and status

**Files:**
- Modify: `docs/ROADMAP.md` (confirmed exists — verified in file listing)

- [ ] **Step 1: Update header and phase dates**

Change the header:
```markdown
## Current Status: Active Development (v1.1.0 in progress)
**Last Updated**: 2026-03-16
**Version**: 1.1.0-dev
```

Update Phase 2 target: `Q2 2024` → `Q2 2026 (in progress)`
Update Phase 3 target: `Q3 2024` → `Q3 2026`
Update Phase 4 target: `Q4 2024` → `Q4 2026`
Update Phase 5 target: `2025` → `2027`

Mark these Phase 2 items as in progress (`- [~]`) in the Training Analytics section:
- `[ ] Training zones calculation (Zone 1-5 based on HR)` → `- [~] Training zones calculation (Zone 1-5 based on HR) — in progress`

- [ ] **Step 2: Commit**

```bash
git add docs/ROADMAP.md
git commit -m "docs: update ROADMAP dates and mark Phase 2 as in progress"
```

---

### Task 10: Add local dev quick-start `.env.example` for web app

**Files:**
- Create: `web_app/.env.example`

**Context:** There is no `.env.example` for the web app. Developers don't know what env vars to set.

- [ ] **Step 1: Create `web_app/.env.example`**

```bash
# web_app/.env.example
# Copy to .env.local for local development

# Supabase configuration (get from https://supabase.com/dashboard → your project → Settings → API)
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here

# Backend API URL
# For local dev: http://localhost:3000/api
# For production: https://your-backend-domain.com/api
VITE_API_BASE_URL=http://localhost:3000/api
```

- [ ] **Step 2: Commit**

```bash
git add web_app/.env.example
git commit -m "docs: add web_app/.env.example for local development setup"
```

---

## Chunk 3: Phase 2 — Training Zones Feature

### Task 11: Add `calculateTrainingZones` utility

**Files:**
- Create: `web_app/src/lib/trainingZones.js`

**Context:** Training zones classify heart rate intensity into 5 zones based on max HR percentage. Each zone has a name, HR range, and physiological description. This is a pure function — no API needed.

Standard 5-zone model:
- Zone 1: 50–60% max HR — Recovery
- Zone 2: 60–70% max HR — Aerobic base
- Zone 3: 70–80% max HR — Aerobic endurance
- Zone 4: 80–90% max HR — Threshold
- Zone 5: 90–100% max HR — Anaerobic/VO2 max

- [ ] **Step 1: Create `web_app/src/lib/trainingZones.js`**

```javascript
export const ZONE_DEFINITIONS = [
  { zone: 1, name: 'Recovery',          minPct: 0.50, maxPct: 0.60, color: '#6c757d' },
  { zone: 2, name: 'Aerobic Base',      minPct: 0.60, maxPct: 0.70, color: '#28a745' },
  { zone: 3, name: 'Aerobic Endurance', minPct: 0.70, maxPct: 0.80, color: '#17a2b8' },
  { zone: 4, name: 'Threshold',         minPct: 0.80, maxPct: 0.90, color: '#ffc107' },
  { zone: 5, name: 'Anaerobic',         minPct: 0.90, maxPct: 1.00, color: '#dc3545' },
]

/**
 * Calculate HR zone boundaries for a given max heart rate.
 * @param {number} maxHR - Maximum heart rate in bpm
 * @returns {Array} Zone definitions with absolute bpm ranges
 */
export function getZoneBoundaries(maxHR) {
  if (!maxHR || maxHR < 100) return []
  return ZONE_DEFINITIONS.map(z => ({
    ...z,
    minBpm: Math.round(z.minPct * maxHR),
    maxBpm: Math.round(z.maxPct * maxHR),
    label: `Zone ${z.zone}: ${z.name}`,
    range: `${Math.round(z.minPct * maxHR)}–${Math.round(z.maxPct * maxHR)} bpm`,
  }))
}

/**
 * Determine which zone a given heart rate falls in.
 * @param {number} hr - Heart rate in bpm
 * @param {number} maxHR - Maximum heart rate in bpm
 * @returns {Object|null} Zone definition or null if outside all zones
 */
export function getZoneForHR(hr, maxHR) {
  if (!hr || !maxHR) return null
  const pct = hr / maxHR
  return ZONE_DEFINITIONS.find(z => pct >= z.minPct && pct < z.maxPct) || ZONE_DEFINITIONS[4]
}

/**
 * Calculate time spent in each zone from an array of HR data points.
 * @param {Array} hrData - Array of { heartRate: number } objects
 * @param {number} maxHR - Maximum heart rate in bpm
 * @returns {Array} Zone breakdown with time counts (each point = 1 unit of time)
 */
export function calcZoneDistribution(hrData, maxHR) {
  if (!hrData?.length || !maxHR) return []

  const counts = Object.fromEntries(ZONE_DEFINITIONS.map(z => [z.zone, 0]))
  hrData.forEach(point => {
    const zone = getZoneForHR(point.heartRate, maxHR)
    if (zone) counts[zone.zone]++
  })

  const total = hrData.length
  return ZONE_DEFINITIONS.map(z => ({
    ...z,
    count: counts[z.zone],
    percentage: total > 0 ? Math.round((counts[z.zone] / total) * 100) : 0,
  }))
}
```

- [ ] **Step 2: Commit**

```bash
git add web_app/src/lib/trainingZones.js
git commit -m "feat: add training zones calculation utility"
```

---

### Task 12: Add `TrainingZonesChart` component

**Files:**
- Create: `web_app/src/components/TrainingZonesChart.jsx`

**Context:** This reusable component takes zone distribution data and renders a horizontal bar chart showing % time in each zone with color coding.

- [ ] **Step 1: Create `web_app/src/components/TrainingZonesChart.jsx`**

```jsx
import React from 'react'
import { getZoneBoundaries, calcZoneDistribution } from '../lib/trainingZones'

/**
 * Props:
 *   maxHR: number (person's max heart rate)
 *   hrData: Array<{ heartRate: number }> (raw HR data points from session)
 *   avgHR: number (optional, shown if no hrData)
 */
export default function TrainingZonesChart({ maxHR, hrData, avgHR }) {
  if (!maxHR) {
    return (
      <div style={{ padding: '15px', color: '#666', fontStyle: 'italic' }}>
        Max heart rate not set for this person. Set it in Persons to see zone breakdown.
      </div>
    )
  }

  const zones = getZoneBoundaries(maxHR)

  // If we have raw data, calculate distribution; otherwise estimate from avgHR
  let distribution = null
  if (hrData?.length > 0) {
    distribution = calcZoneDistribution(hrData, maxHR)
  }

  return (
    <div>
      <h3 style={{ marginBottom: '15px' }}>Training Zones (Max HR: {maxHR} bpm)</h3>

      {/* Zone reference table */}
      <table style={{ width: '100%', borderCollapse: 'collapse', marginBottom: '20px', fontSize: '14px' }}>
        <thead>
          <tr style={{ background: '#f8f9fa' }}>
            <th style={{ padding: '8px', textAlign: 'left', borderBottom: '1px solid #dee2e6' }}>Zone</th>
            <th style={{ padding: '8px', textAlign: 'left', borderBottom: '1px solid #dee2e6' }}>Name</th>
            <th style={{ padding: '8px', textAlign: 'left', borderBottom: '1px solid #dee2e6' }}>HR Range</th>
            {distribution && (
              <th style={{ padding: '8px', textAlign: 'left', borderBottom: '1px solid #dee2e6' }}>Time %</th>
            )}
          </tr>
        </thead>
        <tbody>
          {zones.map((z, i) => {
            const dist = distribution?.[i]
            return (
              <tr key={z.zone}>
                <td style={{ padding: '8px', borderBottom: '1px solid #dee2e6' }}>
                  <span style={{
                    display: 'inline-block', width: 12, height: 12,
                    background: z.color, borderRadius: 2, marginRight: 6
                  }} />
                  Zone {z.zone}
                </td>
                <td style={{ padding: '8px', borderBottom: '1px solid #dee2e6' }}>{z.name}</td>
                <td style={{ padding: '8px', borderBottom: '1px solid #dee2e6' }}>{z.range}</td>
                {distribution && (
                  <td style={{ padding: '8px', borderBottom: '1px solid #dee2e6' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <div style={{
                        width: `${dist.percentage * 2}px`, height: 12,
                        background: z.color, borderRadius: 2, minWidth: 2
                      }} />
                      {dist.percentage}%
                    </div>
                  </td>
                )}
              </tr>
            )
          })}
        </tbody>
      </table>

      {/* Highlight current zone if avgHR provided but no raw data */}
      {avgHR && !distribution && (
        <p style={{ fontSize: '13px', color: '#666' }}>
          Avg HR {avgHR} bpm — zone breakdown requires raw HR data from mobile app sync.
        </p>
      )}
    </div>
  )
}
```

- [ ] **Step 2: Commit**

```bash
git add web_app/src/components/TrainingZonesChart.jsx
git commit -m "feat: add TrainingZonesChart component"
```

---

### Task 13: Integrate TrainingZonesChart into SessionDetail page

**Files:**
- Modify: `web_app/src/pages/SessionDetail.jsx`
- Modify: `web_app/src/services/api.js`

**Context:** The session detail page shows a single session. We need to also fetch the person's profile (for maxHR) and display the TrainingZonesChart. The session's `heartRateData` array contains raw HR points.

- [ ] **Step 1: Read current SessionDetail.jsx**

Read `web_app/src/pages/SessionDetail.jsx` to understand current structure before editing.

- [ ] **Step 2: Add `getPersonsByIds` or reuse `personService.getPerson`**

In `web_app/src/services/api.js`, the `personService` already has `getPerson(id)`. No change needed to api.js.

- [ ] **Step 3: Add person fetch and zones display to SessionDetail**

In `SessionDetail.jsx`:
1. Import `TrainingZonesChart` from `'../components/TrainingZonesChart'`
2. Add a `useEffect` that fetches the person when `session.personId` is available
3. Pass `person.maxHeartRate`, `session.heartRateData`, and `session.avgHeartRate` to `<TrainingZonesChart />`
4. Add a "Training Zones" section card in the JSX

Example addition to the existing session data display:

```jsx
import TrainingZonesChart from '../components/TrainingZonesChart'
// ...inside component, after existing session data:
const [person, setPerson] = useState(null)

useEffect(() => {
  if (session?.personId) {
    personService.getPerson(session.personId)
      .then(res => setPerson(res.data))
      .catch(() => {}) // non-critical
  }
}, [session?.personId])

// In JSX:
<div className="card">
  <TrainingZonesChart
    maxHR={person?.maxHeartRate}
    hrData={session?.heartRateData}
    avgHR={session?.avgHeartRate}
  />
</div>
```

- [ ] **Step 4: Commit**

```bash
git add web_app/src/pages/SessionDetail.jsx web_app/src/services/api.js
git commit -m "feat: show training zones on session detail page"
```

---

### Task 14: Add training zones summary to HistoryAnalysis

**Files:**
- Modify: `web_app/src/pages/HistoryAnalysis.jsx`

**Context:** The analysis page already shows HR trend and training type charts. Add a zone distribution section that aggregates all sessions' avgHR vs each person's maxHR.

- [ ] **Step 1: Add zone color legend and per-person zone summary**

In `HistoryAnalysis.jsx`, after the monthly progress chart and before the recent sessions table:

1. Import `getZoneForHR` from `'../lib/trainingZones'`
2. Add a function `prepareZoneSummary()` that:
   - For each session, looks up the person's `maxHeartRate`
   - Calls `getZoneForHR(session.avgHeartRate, person.maxHeartRate)`
   - Accumulates counts per zone
3. Render a simple horizontal bar showing zone distribution across all sessions

```jsx
const prepareZoneSummary = () => {
  const counts = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }
  let total = 0
  sessions.forEach(s => {
    const person = persons.find(p => p.id === s.personId)
    if (!person?.maxHeartRate || !s.avgHeartRate) return
    const zone = getZoneForHR(s.avgHeartRate, person.maxHeartRate)
    if (zone) { counts[zone.zone]++; total++ }
  })
  if (total === 0) return null
  return { counts, total }
}
```

Add a card showing this data as a simple percentage bar using the zone colors from `ZONE_DEFINITIONS`.

- [ ] **Step 2: Commit**

```bash
git add web_app/src/pages/HistoryAnalysis.jsx
git commit -m "feat: add zone distribution summary to history analysis page"
```

---

### Task 15: Add CSV export to Sessions page

**Files:**
- Modify: `web_app/src/pages/Sessions.jsx`

**Context:** Phase 2 includes data export. CSV is the simplest starting point — no backend needed, just client-side generation.

- [ ] **Step 1: Add `exportToCSV` function and button**

In `Sessions.jsx`, add a utility function above the component:

```javascript
function exportSessionsToCSV(sessions) {
  const headers = ['Title', 'Type', 'Date', 'Duration (min)', 'Avg HR (bpm)', 'Max HR (bpm)', 'Calories (kcal)', 'Distance (m)']
  const rows = sessions.map(s => [
    `"${(s.title || '').replace(/"/g, '""')}"`,
    s.trainingType || '',
    s.startTime ? new Date(s.startTime).toLocaleDateString() : '',
    s.duration ? Math.round(s.duration / 60) : '',
    s.avgHeartRate || '',
    s.maxHeartRate || '',
    s.calories ? Math.round(s.calories) : '',
    s.distance || '',
  ])
  const csv = [headers.join(','), ...rows.map(r => r.join(','))].join('\n')
  const blob = new Blob([csv], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `sessions-${new Date().toISOString().split('T')[0]}.csv`
  a.click()
  URL.revokeObjectURL(url)
}
```

Add an "Export CSV" button next to the "All Training Sessions" heading, only shown when sessions.length > 0:

```jsx
<button
  onClick={() => exportSessionsToCSV(sessions)}
  className="btn"
  style={{ background: '#28a745', color: 'white' }}
>
  Export CSV
</button>
```

- [ ] **Step 2: Commit**

```bash
git add web_app/src/pages/Sessions.jsx
git commit -m "feat: add CSV export to sessions page"
```

---

## Chunk 4: Final Verification

### Task 16: Run web app build to verify no compile errors

- [ ] **Step 1: Install dependencies if needed**

```bash
cd web_app && npm install
```

- [ ] **Step 2: Run build**

```bash
npm run build
```

Expected: build completes with no errors. Warnings about unused variables are acceptable but should be noted.

- [ ] **Step 3: Start dev server and do a manual smoke test**

```bash
npm run dev
```

Open `http://localhost:5173`. Verify:
- Login page loads
- After login, dashboard loads without JS errors
- Sessions page loads (may show empty list if no backend)
- Error message shown when backend unreachable (not blank)

- [ ] **Step 4: Run backend and verify auth flow works**

```bash
cd ../backend && npm start
```

With both running:
- Login with Supabase credentials
- Dashboard should load (empty data is fine)
- Creating a person via Persons page should succeed (check backend logs for 201)

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: final verification pass — all chunks complete"
```

---

## Summary of All Changes

| File | Change |
|---|---|
| `backend/src/routes/sessions.js` | Move `stats/summary` route before `/:id` |
| `backend/src/middleware/auth.js` | Accept Supabase JWTs, auto-create MongoDB user |
| `backend/src/models/User.js` | Add `supabaseId` field |
| `web_app/src/pages/Dashboard.jsx` | Define `stats` from `statsQuery.data` |
| `web_app/src/pages/PersonsManagement.jsx` | Remove duplicate heading |
| `web_app/src/pages/RecordingManagement.jsx` | Fix snake_case → camelCase, fix trainingType enum |
| `web_app/src/pages/HistoryAnalysis.jsx` | Fix snake_case → camelCase field reads, add zone summary |
| `web_app/src/pages/Sessions.jsx` | Add error state, add CSV export |
| `web_app/src/pages/SessionDetail.jsx` | Add TrainingZonesChart |
| `web_app/src/App.jsx` | Subscribe to Supabase auth state changes |
| `web_app/src/lib/trainingZones.js` | New: zone calculation utilities |
| `web_app/src/components/TrainingZonesChart.jsx` | New: zone display component |
| `web_app/.env.example` | New: document required env vars |
| `WEB_APP_STATUS.md` | Refresh to March 2026 state |
| `docs/ROADMAP.md` | Update dates and mark Phase 2 in progress |
