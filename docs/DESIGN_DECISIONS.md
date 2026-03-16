# Architecture & Design Decisions

**Project:** Linglong Heart Rate Monitor Platform  
**Last Updated:** 2026-01-02  
**Phase:** Architecture & Design

---

## Table of Contents
1. [System Architecture](#1-system-architecture)
2. [Technology Stack Decisions](#2-technology-stack-decisions)
3. [Data Model Design](#3-data-model-design)
4. [API Design](#4-api-design)
5. [Security Architecture](#5-security-architecture)
6. [Design Patterns](#6-design-patterns)
7. [Key Design Decisions](#7-key-design-decisions)

---

## 1. System Architecture

### 1.1 Three-Tier Architecture

**Decision:** Implement three-tier architecture with clear separation of concerns

```
┌─────────────────────────────────────────────────────┐
│         Presentation Layer                          │
├─────────────────────┬───────────────────────────────┤
│  Mobile App         │   Web Application             │
│  (Flutter)          │   (React)                     │
│  - BLE Scanning     │   - Analytics                 │
│  - HR Monitoring    │   - Reports                   │
│  - Local Storage    │   - Visualizations            │
└──────────┬──────────┴──────────┬────────────────────┘
           │                     │
           │ HTTP/REST API       │
           │                     │
┌──────────▼─────────────────────▼────────────────────┐
│         Application Layer                           │
│  Backend Server (Node.js/Express)                   │
│  - Authentication (JWT)                             │
│  - Business Logic                                   │
│  - Data Validation                                  │
└──────────┬──────────────────────────────────────────┘
           │
           │ PostgreSQL
           │
┌──────────▼──────────────────────────────────────────┐
│         Data Layer                                  │
│  Supabase (PostgreSQL + Auth)                       │
│  - User accounts                                    │
│  - Training sessions                                │
│  - Person profiles                                  │
└─────────────────────────────────────────────────────┘
```

**Rationale:**
- ✅ Clear separation of concerns
- ✅ Independent scaling of each tier
- ✅ Technology flexibility
- ✅ Easier testing and maintenance

---

## 2. Technology Stack Decisions

### 2.1 Mobile: Flutter

**Decision:** Use Flutter for cross-platform mobile development

**Alternatives Considered:**
- React Native
- Native iOS/Android (separate codebases)
- Xamarin
- Ionic

**Selected:** Flutter

**Rationale:**
- ✅ Single codebase for iOS + Android
- ✅ Excellent BLE support (flutter_blue_plus)
- ✅ Native performance
- ✅ Rich widget library (Material Design)
- ✅ Strong community support
- ✅ Good for real-time UI updates

**Trade-offs:**
- ⚠️ Dart language learning curve
- ⚠️ Larger app size than native

### 2.2 Backend: Node.js + Express

**Decision:** Use Node.js with Express framework

**Alternatives Considered:**
- Python (Django/Flask)
- Go
- Java (Spring Boot)
- Ruby on Rails

**Selected:** Node.js + Express

**Rationale:**
- ✅ JavaScript ecosystem (same language as web frontend potential)
- ✅ Lightweight and fast
- ✅ Excellent for REST APIs
- ✅ Large package ecosystem (npm)
- ✅ Easy deployment
- ✅ Good real-time support (Socket.io potential)

### 2.3 Database: Supabase (PostgreSQL)

**Decision:** Use Supabase for database and authentication

**Alternatives Considered:**
- MongoDB + custom auth
- Firebase
- AWS Amplify
- Self-hosted PostgreSQL

**Selected:** Supabase (PostgreSQL)

**Rationale:**
- ✅ PostgreSQL (ACID compliance, relational data)
- ✅ Built-in authentication (JWT)
- ✅ Real-time subscriptions
- ✅ Row-level security
- ✅ Open-source
- ✅ Self-hosting option
- ✅ Good free tier

**Migration from MongoDB:**
- Initial design used MongoDB
- Switched to Supabase for better auth integration
- PostgreSQL better for relational queries (user→person→sessions)

### 2.4 Web: React + Vite

**Decision:** Use React with Vite build tool

**Alternatives Considered:**
- Vue.js
- Angular
- Svelte
- Next.js

**Selected:** React + Vite

**Rationale:**
- ✅ Most popular framework (ecosystem)
- ✅ Component-based architecture
- ✅ Vite for fast development (HMR)
- ✅ Easy to learn
- ✅ Great charting libraries (Recharts)

### 2.5 Local Storage: Hive (Mobile)

**Decision:** Use Hive for local mobile storage

**Alternatives Considered:**
- SQLite (sqflite)
- Shared Preferences
- Realm
- ObjectBox

**Selected:** Hive

**Rationale:**
- ✅ NoSQL (flexible schema)
- ✅ Fast performance
- ✅ Simple API
- ✅ Type-safe with code generation
- ✅ Works offline
- ✅ Small footprint

---

## 3. Data Model Design

### 3.1 Entity Relationship Diagram

```
┌──────────────┐
│    User      │
│──────────────│
│ id (PK)      │
│ email        │
│ password     │
│ name         │
│ role         │
│ created_at   │
└──────┬───────┘
       │
       │ 1:N
       │
┌──────▼───────┐
│   Person     │
│──────────────│
│ id (PK)      │
│ user_id (FK) │
│ name         │
│ age          │
│ gender       │
│ weight       │
│ height       │
│ max_hr       │
│ resting_hr   │
│ created_at   │
│ updated_at   │
└──────┬───────┘
       │
       │ 1:N
       │
┌──────▼──────────────┐
│  Training Session   │
│─────────────────────│
│ id (PK)             │
│ user_id (FK)        │
│ person_id (FK)      │
│ title               │
│ start_time          │
│ end_time            │
│ duration            │
│ training_type       │
│ avg_heart_rate      │
│ max_heart_rate      │
│ min_heart_rate      │
│ calories            │
│ heart_rate_data     │ (JSONB array)
│ notes               │
│ created_at          │
└─────────────────────┘
```

### 3.2 Heart Rate Data Structure

**Design Decision:** Store HR data as JSONB array within session

**Alternative:** Separate HR data points table

**Selected:** JSONB array

```json
{
  "heart_rate_data": [
    {
      "timestamp": "2026-01-02T10:00:00Z",
      "heartRate": 120,
      "deviceId": "polar-h10-abc123"
    },
    {
      "timestamp": "2026-01-02T10:00:01Z",
      "heartRate": 122,
      "deviceId": "polar-h10-abc123"
    }
  ]
}
```

**Rationale:**
- ✅ Single query for session + HR data
- ✅ Atomic updates
- ✅ PostgreSQL JSONB indexing and queries
- ⚠️ Session size limit consideration (for very long sessions)

### 3.3 RR Interval Data (Phase 2)

**Design Decision:** Separate table for RR intervals

```sql
CREATE TABLE rr_intervals (
  id UUID PRIMARY KEY,
  session_id UUID REFERENCES training_sessions(id),
  intervals JSONB, -- array of {timestamp, rr_ms, quality}
  created_at TIMESTAMP
);
```

**Rationale:**
- Large datasets (1000s of points per session)
- Separate querying for HRV analysis
- Optional data (not all sessions need RR)

---

## 4. API Design

### 4.1 RESTful Principles

**Decision:** Follow REST architectural style

**Endpoints Structure:**
```
/api/auth/register      POST    - User registration
/api/auth/login         POST    - User authentication
/api/persons            GET     - List persons
/api/persons            POST    - Create/update person
/api/persons/:id        GET     - Get person details
/api/sessions           GET     - List sessions
/api/sessions           POST    - Create/update session
/api/sessions/:id       GET     - Get session details
/api/sessions/:id       DELETE  - Delete session
/api/sessions/stats     GET     - Session statistics
```

### 4.2 Authentication Pattern

**Decision:** JWT (JSON Web Tokens) for stateless authentication

**Flow:**
```
1. User login → Supabase Auth → JWT token
2. Client stores token (secure storage)
3. Every API request includes: Authorization: Bearer <token>
4. Backend validates token via Supabase
5. Extract user ID from token
6. Use user ID for data isolation
```

**Rationale:**
- ✅ Stateless (scalable)
- ✅ Secure (signed tokens)
- ✅ Standard approach
- ✅ Built into Supabase

### 4.3 Data Synchronization Strategy

**Decision:** Optimistic UI + Background sync

**Pattern:**
1. Mobile app stores data locally immediately (Hive)
2. UI updates instantly (optimistic)
3. Background service syncs to server
4. Conflict resolution: server wins (with user notification)
5. Track sync status per record

**Rationale:**
- ✅ Offline-first experience
- ✅ Fast UI response
- ✅ Network independence
- ⚠️ Potential conflicts (mitigated by timestamps)

---

## 5. Security Architecture

### 5.1 Authentication & Authorization

**Layers:**
```
1. Supabase Auth (email/password)
2. JWT token validation
3. Row-level security (PostgreSQL)
4. API middleware (protect routes)
```

### 5.2 Data Protection

| Layer | Mechanism | Purpose |
|-------|-----------|---------|
| Transport | HTTPS/TLS | Encrypt in transit |
| Storage (mobile) | flutter_secure_storage | Encrypt tokens |
| Storage (server) | PostgreSQL encryption | Encrypt at rest |
| Passwords | bcrypt hashing | Password security |
| Tokens | JWT signing | Token integrity |

### 5.3 Data Isolation

**Decision:** User-scoped data access enforced at multiple levels

**Implementation:**
1. **API Level:** Extract user_id from JWT
2. **Database Level:** All queries include user_id filter
3. **RLS (Row Level Security):** PostgreSQL policies
4. **Validation:** Prevent user_id spoofing in requests

---

## 6. Design Patterns

### 6.1 Mobile App (Flutter)

**State Management:** Provider pattern

**Rationale:**
- ✅ Official recommendation
- ✅ Simple and performant
- ✅ Dependency injection
- ✅ Rebuild optimization

**Service Layer Pattern:**
```
Screens → Providers → Services → Models
```

**Services:**
- `BLEService` - Bluetooth management
- `DatabaseService` - Local storage
- `SyncService` - Cloud synchronization

### 6.2 Backend (Node.js)

**MVC-like Pattern:**
```
Routes → Middleware → Controllers → Services → Database
```

**Middleware Stack:**
1. CORS
2. Body parser
3. Authentication (JWT validation)
4. Route handler
5. Error handler

### 6.3 Data Access Pattern

**Repository Pattern (implicit):**
- Supabase client acts as repository
- Service layer abstracts database operations
- No direct Supabase calls in routes

---

## 7. Key Design Decisions

### 7.1 Offline-First Architecture

**Decision:** Mobile app works completely offline

**Implementation:**
- Local storage (Hive) as primary data source
- Sync to cloud as secondary operation
- Background sync with retry logic
- Conflict resolution strategy

**Rationale:**
- Training sessions happen anywhere (no network)
- User experience not dependent on connectivity
- Data safety (not lost if network fails)

### 7.2 Multi-Sensor Support

**Decision:** Support multiple simultaneous BLE connections

**Implementation:**
- `BLEService` manages multiple device connections
- Device list with connection states
- Individual HR streams per device
- Average HR calculation across devices

**Rationale:**
- Team monitoring use case
- Coach monitoring multiple athletes
- Redundancy (backup sensors)

### 7.3 Platform Focus: Mobile-First

**Decision:** Mobile app is primary interface, web is secondary (analytics)

**Rationale:**
- HR monitoring requires mobile (BLE sensors)
- Real-time monitoring needs portability
- Web best for historical analysis
- Matches user workflow (train → analyze)

### 7.4 No Real-Time Sync During Training

**Decision:** Sync after session, not during

**Rationale:**
- Battery conservation
- Network independence
- Reduced complexity
- Less risk of data loss
- Sync can happen in background later

### 7.5 Open Source + Self-Hostable

**Decision:** MIT license, support self-hosting

**Rationale:**
- Data ownership for users
- No vendor lock-in
- Academic/research use
- Community contributions
- Privacy-conscious users

---

## 8. Future Architecture Considerations

### 8.1 Microservices (Phase 5)

**Potential Split:**
- Auth service
- Data ingestion service
- Analytics service
- Reporting service

**When:** If scale exceeds 100k users

### 8.2 Real-Time Features (Phase 3)

**Technology:** WebSockets (Socket.io)

**Use Cases:**
- Live team monitoring dashboard
- Real-time coaching feedback
- Multi-coach collaboration

### 8.3 GraphQL API (Phase 5)

**Alternative to REST for complex queries**

**Benefits:**
- Flexible queries
- Reduced over-fetching
- Better for complex analytics

---

## 9. Design Trade-offs

| Decision | Benefit | Trade-off |
|----------|---------|-----------|
| Flutter | Cross-platform | Larger app size |
| Supabase | Easy setup | Vendor dependency |
| Offline-first | Works anywhere | Sync complexity |
| JSONB for HR data | Simple queries | Size limits |
| JWT auth | Stateless | Token size |
| Hive storage | Fast | No SQL queries |

---

## 10. Decision Log

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2024-01 | Use Flutter | Cross-platform | Mobile dev |
| 2024-01 | Supabase over MongoDB | Auth + PostgreSQL | Backend migration |
| 2026-01 | Add RR intervals | HRV analysis | Data model |
| 2026-01 | Phase 2 focus on HR | Scope clarity | Feature set |

---

**Review Cycle:** Quarterly architecture review  
**Next Review:** 2026-04-01  
**Owner:** Technical Lead
