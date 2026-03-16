# System Integration Status

**Date:** January 6, 2026

## Current Architecture

```
Mobile App (Flutter) ──────┐
                           ├──> Backend API (Node.js) ──> Supabase
Web App (React) ───────────┘                              Database
```

**Note:** Web app now connects DIRECTLY to Supabase (bypassing backend for data queries)

---

## 1. Backend Server ✅

**Status:** Running on http://localhost:3000

**Endpoints:**
- `GET /api/health` - Health check ✅
- `POST /api/auth/login` - Authentication
- `GET /api/persons` - Get persons
- `GET /api/sessions` - Get training sessions
- `GET /api/sessions/stats/summary` - Get statistics

**Configuration:**
- Port: 3000
- Database: Supabase (via Supabase client)
- CORS: Enabled for all origins

**To start:** 
```bash
cd /Users/zhaojia/linglong/backend
npm start
```

---

## 2. Web App ✅

**Status:** Deployed to Cloudflare Pages

**Live URL:** https://ca86b7cb.linglong-test.pages.dev

**Data Access:** 
- **Authentication:** Supabase Auth (direct)
- **Data Queries:** Supabase Database (direct via Supabase JS client)
- **Backend API:** Not used (bypassed)

**Environment Variables:**
- `VITE_SUPABASE_URL`: https://krbobzpwgzxhnqssgwoy.supabase.co
- `VITE_SUPABASE_ANON_KEY`: Configured in `.env.production`

**Local Development:**
```bash
cd /Users/zhaojia/linglong/web_app
npm run dev  # Port 5173 or 5174
```

**Deploy:**
```bash
npm run build
npx wrangler pages deploy dist --project-name=linglong-test
```

---

## 3. Mobile App ⚠️

**Status:** Partially configured

**API Configuration:**
- Default Backend: http://localhost:3000/api
- Supabase URL: https://krbobzpwgzxhnqssgwoy.supabase.co
- Supabase Key: Hardcoded in `supabase_client.dart`

**Issues:**
- Mobile uses backend API, but web app doesn't
- localhost backend won't work on physical devices
- Need to align mobile to use Supabase directly like web app

**To run:**
```bash
cd /Users/zhaojia/linglong/mobile_app
flutter run
```

---

## 4. Database (Supabase) ⚠️

**Status:** Tables need to be created

**Project:** https://krbobzpwgzxhnqssgwoy.supabase.co

**Required Tables:**
- `public.persons` - User profiles
- `public.training_sessions` - Training session data

**Setup Required:**
1. Go to: https://supabase.com/dashboard/project/krbobzpwgzxhnqssgwoy/sql/new
2. Paste SQL from: `/Users/zhaojia/linglong/complete_setup.sql`
3. Click "RUN"

**RLS Policies:** Required for data access control

---

## Integration Issues

### ❌ Critical Issues

1. **Database tables don't exist**
   - Web app shows: "Could not find the table 'public.training_sessions'"
   - Fix: Run `complete_setup.sql` in Supabase SQL Editor

2. **Mobile app uses backend, web app doesn't**
   - Mobile: Backend API → Supabase
   - Web: Direct Supabase access
   - Recommendation: Align mobile to use Supabase directly

### ⚠️ Configuration Mismatches

1. **Backend is optional for web but required for mobile**
   - Web app works without backend
   - Mobile app requires backend running on localhost

2. **Mobile won't work on physical devices**
   - localhost:3000 only works on emulator
   - Need to either:
     - Deploy backend to cloud OR
     - Switch mobile to direct Supabase access (recommended)

---

## Recommended Next Steps

### Immediate (to make web app work):
1. ✅ Backend is running
2. ⏳ **Run SQL in Supabase** (complete_setup.sql) - BLOCKED ON USER
3. ⏳ Refresh web app

### Short-term (to align architecture):
1. Update mobile app to use Supabase directly (like web app)
2. Remove backend API dependency from mobile
3. Keep backend for admin functions only (optional)

### Long-term (for production):
1. Deploy backend to cloud service (if needed)
2. Use environment variables for all API endpoints
3. Set up proper authentication flow
4. Add error handling and retry logic

---

## Quick Test Commands

**Test Backend:**
```bash
curl http://localhost:3000/api/health
```

**Test Web App Locally:**
```bash
cd web_app && npm run dev
# Open http://localhost:5173
```

**Test Mobile App:**
```bash
cd mobile_app && flutter run
```

**Check Supabase Tables:**
```bash
cd supabase && supabase db pull
```

---

## Files to Check

**Backend:**
- `/Users/zhaojia/linglong/backend/src/server.js` - Main server
- `/Users/zhaojia/linglong/backend/src/routes/*` - API routes

**Web App:**
- `/Users/zhaojia/linglong/web_app/src/services/api.js` - API client
- `/Users/zhaojia/linglong/web_app/.env.production` - Environment variables

**Mobile App:**
- `/Users/zhaojia/linglong/mobile_app/lib/services/sync_service.dart` - Backend API calls
- `/Users/zhaojia/linglong/mobile_app/lib/supabase/supabase_client.dart` - Supabase config

**Database:**
- `/Users/zhaojia/linglong/complete_setup.sql` - Setup script
- `/Users/zhaojia/linglong/supabase/schema.sql` - Schema definition
