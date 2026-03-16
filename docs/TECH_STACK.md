# Tech Stack Summary

**Project:** Linglong Heart Rate Monitor Platform  
**Last Updated:** 2026-01-02

---

## Quick Overview

| Layer | Component | Technology | Purpose |
|-------|-----------|-----------|---------|
| **Mobile** | App Framework | Flutter 3.0+ | iOS/Android cross-platform |
| | State Mgmt | Provider | Reactive updates |
| | Local DB | Hive | Offline data storage |
| | BLE | flutter_blue_plus | Heart rate sensor connectivity |
| | Charts | fl_chart | Real-time HR visualization |
| | Auth Storage | flutter_secure_storage | Secure token storage |
| | Networking | dio, http | API communication |
| **Backend** | Runtime | Node.js 16+ | Server runtime |
| | Framework | Express.js 4 | REST API |
| | Database | Supabase (PostgreSQL) | Cloud database |
| | Auth | Supabase Auth (JWT) | User authentication |
| | Validation | express-validator | Input validation |
| **Web** | Framework | React 18 | UI components |
| | Build Tool | Vite 5 | Fast development & builds |
| | Routing | React Router v6 | Client-side navigation |
| | HTTP Client | Axios | API requests |
| | Charts | Recharts | Data visualization |
| | Date Utils | date-fns | Date manipulation |
| | Backend SDK | Supabase JS Client | Database & auth |

---

## Detailed Descriptions

### 📱 Mobile App (Flutter)

**What it does:**
- Real-time heart rate monitoring from BLE sensors
- Training session recording and local storage
- Offline-first operation
- Background data sync to cloud
- Live HR charts and dashboards
- Multi-sensor support

**Why Flutter:**
- ✅ Single codebase for iOS + Android
- ✅ Native performance
- ✅ Excellent BLE support
- ✅ Rich Material Design components
- ✅ Hot reload for development
- ✅ 60-120 fps animations

**Key Dependencies:**
- `flutter_blue_plus` - BLE connectivity (Bluetooth HR sensors)
- `hive` - Local NoSQL database (works offline)
- `provider` - State management (reactive UI updates)
- `fl_chart` - Real-time heart rate charts
- `dio` - HTTP client (API communication)

**Data Flow:**
```
HR Sensor → BLE → flutter_blue_plus → Hive (local) → UI
                                    ↓ (when online)
                              Sync Service → Backend
```

---

### ☁️ Backend (Node.js + Supabase)

**What it does:**
- RESTful API for mobile and web clients
- User authentication (register, login)
- Training session management
- Training statistics calculations
- Data persistence
- Multi-user data isolation

**Why Node.js:**
- ✅ Lightweight and fast
- ✅ Excellent for REST APIs
- ✅ Large package ecosystem
- ✅ Easy deployment (PaaS friendly)
- ✅ Good async/await support
- ✅ JSON-native (matches mobile/web)

**Why Supabase:**
- ✅ PostgreSQL (ACID compliance, relational)
- ✅ Built-in authentication (JWT)
- ✅ Real-time subscriptions (future feature)
- ✅ Row-level security
- ✅ Self-hosting option
- ✅ Free tier available
- ✅ Open source alternative to Firebase

**Architecture:**
```
Mobile/Web Clients
       ↓
Express.js API Server
       ↓
Supabase (PostgreSQL + Auth)
```

**API Endpoints:**
```
POST   /api/auth/register      - Create user account
POST   /api/auth/login         - Authenticate user
GET    /api/persons            - List athlete profiles
POST   /api/persons            - Create/update profile
GET    /api/sessions           - List training sessions
POST   /api/sessions           - Create session
GET    /api/sessions/:id       - Session details
DELETE /api/sessions/:id       - Delete session
GET    /api/sessions/stats     - Statistics
```

---

### 🌐 Web App (React + Vite)

**What it does:**
- Historical training data analysis
- Session browsing and filtering
- Heart rate charts and visualization
- Training statistics dashboard
- Session details view
- User authentication

**Why React:**
- ✅ Most popular framework
- ✅ Large ecosystem
- ✅ Component reusability
- ✅ Virtual DOM performance
- ✅ Great chart libraries
- ✅ Existing team knowledge (if any)

**Why Vite:**
- ✅ 10-100x faster development builds
- ✅ Instant hot module replacement (HMR)
- ✅ Minimal configuration
- ✅ Optimized production builds
- ✅ Native ES modules support

**Key Components:**
- `Recharts` - Interactive heart rate charts
- `React Router` - Page navigation
- `Axios` - API communication
- `Supabase JS Client` - Direct database access (optional)
- `date-fns` - Date formatting and calculations

**User Interface:**
```
Login Page
    ↓
Dashboard (overview stats)
    ↓
Sessions List (browse training sessions)
    ↓
Session Detail (view HR chart + details)
```

**Data Flow:**
```
User → Web UI (React)
    ↓
Axios HTTP Request
    ↓
Express.js Backend (API)
    ↓
Supabase Database
    ↓
Response → Recharts Visualization
```

---

## Technology Justification

### Mobile: Flutter
- **Goal:** Cross-platform HR monitoring app
- **Alternative:** Native iOS/Android (2x development)
- **Selected:** Flutter (single codebase, BLE support)

### Backend: Node.js + Supabase
- **Goal:** Scalable, maintainable REST API
- **Alternative:** Python (slower), Go (overkill)
- **Selected:** Node.js (lightweight) + Supabase (managed DB)

### Web: React + Vite
- **Goal:** Fast analytics and data visualization
- **Alternative:** Vue (similar), Angular (heavyweight)
- **Selected:** React (ecosystem) + Vite (speed)

---

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────┐
│  User Training Session                              │
│  (Athlete at gym/field)                             │
└────────────────┬────────────────────────────────────┘
                 │
    ┌────────────▼───────────┐
    │   Mobile App (Flutter) │
    │  ─────────────────     │
    │  - BLE scanning        │
    │  - HR data capture     │
    │  - Local storage       │
    │  - Real-time UI        │
    └────────────┬───────────┘
                 │
    ┌────────────▼──────────────────────┐
    │  Local Storage (Hive)             │
    │  ─────────────────────────        │
    │  - Session data                   │
    │  - Person profiles                │
    │  - Authentication tokens          │
    └────────────┬──────────────────────┘
                 │
    ┌────────────▼──────────────────────────────┐
    │  Background Sync (when online)           │
    │  ─────────────────────────────────       │
    │  - Compress data                         │
    │  - Add JWT token                         │
    │  - POST to backend                       │
    └────────────┬─────────────────────────────┘
                 │
    ┌────────────▼──────────────────────────────┐
    │  Backend API (Node.js/Express)           │
    │  ─────────────────────────────────       │
    │  - Validate JWT                          │
    │  - Enforce data isolation                │
    │  - Calculate statistics                  │
    │  - Store in PostgreSQL                   │
    └────────────┬─────────────────────────────┘
                 │
    ┌────────────▼──────────────────────────────┐
    │  Database (Supabase/PostgreSQL)          │
    │  ─────────────────────────────────       │
    │  - User accounts                         │
    │  - Athlete profiles                      │
    │  - Training sessions                     │
    │  - Heart rate data                       │
    └──────────────────────────────────────────┘
                 │
    ┌────────────▼──────────────────────┐
    │  Web App (React/Vite)             │
    │  ─────────────────────────        │
    │  - Query historical data          │
    │  - Display charts (Recharts)      │
    │  - Analytics dashboard            │
    │  - Export functionality           │
    └──────────────────────────────────┘
```

---

## Deployment Architecture

```
┌─────────────────────────────┐
│   Supabase Cloud            │
│  (Database + Auth)          │
│  - PostgreSQL               │
│  - Real-time subscriptions  │
└─────────────────────────────┘

┌─────────────────────────────┐
│   Backend Server (PaaS)     │
│  (Node.js/Express)          │
│  - Heroku, Railway, etc.    │
│  - Stateless API            │
└─────────────────────────────┘

┌─────────────────────────────┐
│   Web App (Static Host)     │
│  (React/Vite build)         │
│  - Vercel, Netlify, etc.    │
│  - CDN for assets           │
└─────────────────────────────┘

┌─────────────────────────────┐
│   Mobile Apps (App Stores)  │
│  (Flutter builds)           │
│  - Google Play              │
│  - Apple App Store          │
└─────────────────────────────┘
```

---

## Development Environment

### Local Development Setup

**Mobile:**
```bash
cd mobile_app
flutter pub get
flutter run
```

**Backend:**
```bash
cd backend
npm install
npm run dev
```

**Web:**
```bash
cd web_app
npm install
npm run dev  # http://localhost:5173
```

### Dependencies
- Flutter 3.0+
- Node.js 16+
- npm/yarn
- Supabase account (free tier available)

---

## Version Information

**Current Versions (as of 2026-01-02):**
- Flutter: 3.0+
- React: 18.2.0
- Vite: 5.0.7
- Node.js: 16+
- Supabase: 2.48.0
- Express.js: 4.18.2

---

## Future Tech Considerations

### Phase 3 (Team Features)
- WebSockets (Socket.io) for real-time coaching
- Potentially React Native for iPad app (optional)

### Phase 4 (Integrations)
- GraphQL API (alternative to REST)
- Message queues for heavy processing
- Caching layer (Redis)

### Phase 5 (Enterprise)
- Kubernetes deployment
- Microservices architecture
- Advanced monitoring (Datadog, etc.)

---

**Summary:** A modern, practical tech stack optimized for cross-platform heart rate monitoring with clear separation between mobile (real-time), backend (data management), and web (analytics).
