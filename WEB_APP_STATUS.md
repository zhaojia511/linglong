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
