# Requirements Documentation

**Project:** Linglong Heart Rate Monitor Platform  
**Last Updated:** 2026-01-02  
**Phase:** Requirements Gathering & Analysis

---

## 1. Project Vision

### 1.1 Purpose
Create an **open-source heart rate monitoring and training load analysis platform** for athletes, coaches, and sports scientists, inspired by commercial systems like Polar Team Pro and Kubios HRV.

### 1.2 Scope
- **In Scope:** Heart rate monitoring, HRV analysis, training load calculations
- **Out of Scope:** GPS tracking, speed sensors, power meters, video analysis

### 1.3 Target Users
- Individual athletes tracking training load
- Coaches monitoring team/athlete heart rate
- Sports scientists conducting research
- Fitness enthusiasts optimizing training

---

## 2. Functional Requirements

### 2.1 Core Features (Phase 1 - v1.0.0) ✅

#### FR-001: BLE Heart Rate Monitoring
- **Priority:** Critical
- **Description:** Connect to Bluetooth Low Energy heart rate sensors
- **Acceptance Criteria:**
  - Support standard BLE Heart Rate Service (0x180D)
  - Connect to multiple sensors simultaneously (up to 60)
  - Compatible with Polar, Garmin, Wahoo, and other BLE HR monitors
  - Display real-time heart rate (BPM)
  - Show battery level when available
  - Display signal strength (RSSI)

#### FR-002: Training Session Recording
- **Priority:** Critical
- **Description:** Record and store training sessions with heart rate data
- **Acceptance Criteria:**
  - Start/stop session recording
  - Capture timestamp, duration, HR data points
  - Calculate automatic statistics (avg, max, min HR)
  - Estimate calories burned
  - Store sessions locally (offline-first)
  - Associate sessions with person profiles

#### FR-003: Person Profile Management
- **Priority:** High
- **Description:** Manage athlete/user profiles with physiological data
- **Acceptance Criteria:**
  - Create/edit person profiles
  - Store: name, age, gender, weight, height
  - Store: max HR, resting HR
  - Support multiple profiles
  - Profile selection for sessions

#### FR-004: Data Synchronization
- **Priority:** High
- **Description:** Sync data between mobile app, backend, and web
- **Acceptance Criteria:**
  - Cloud backup of training data
  - JWT-based authentication
  - Automatic sync when online
  - Conflict resolution
  - Sync status indicators

#### FR-005: Historical Data Analysis
- **Priority:** High
- **Description:** View and analyze past training sessions
- **Acceptance Criteria:**
  - List all sessions with filters
  - View detailed session data
  - Heart rate charts/graphs
  - Date range filtering
  - Session statistics summary
  - Delete sessions

### 2.2 Phase 2 Features (v1.1.0) - Planned 🔄

#### FR-101: RR Interval Data Capture
- **Priority:** Critical for HRV
- **Description:** Record beat-to-beat RR intervals from sensors
- **Acceptance Criteria:**
  - Capture RR interval data during sessions
  - Store RR intervals with timestamps
  - Data quality validation
  - Export RR interval data
  - Minimum 5-minute recordings for HRV

#### FR-102: Heart Rate Zone Configuration
- **Priority:** High
- **Description:** Customizable HR training zones
- **Acceptance Criteria:**
  - Define 5-zone model (% max HR)
  - Karvonen method (HR Reserve)
  - Custom zone boundaries
  - Per-person zone configuration
  - Zone visualization in sessions

#### FR-103: Training Load Calculation (TRIMP)
- **Priority:** High
- **Description:** Calculate training impulse scores
- **Acceptance Criteria:**
  - Edwards TRIMP (zone-based)
  - Banister TRIMP (exponential)
  - Lucia TRIMP (3-zone)
  - Historical TRIMP tracking
  - TRIMP trends/charts

#### FR-104: ACWR (Acute:Chronic Workload Ratio)
- **Priority:** High
- **Description:** Monitor training load progression
- **Acceptance Criteria:**
  - Calculate 7-day acute load
  - Calculate 28-day chronic load
  - ACWR ratio and visualization
  - Injury risk indicators
  - Optimal training zone display

#### FR-105: HRV Metrics Calculation
- **Priority:** High
- **Description:** Heart rate variability analysis
- **Acceptance Criteria:**
  - Time-domain: SDNN, RMSSD, pNN50
  - Frequency-domain: LF, HF, LF/HF ratio
  - HRV trends over time
  - Recovery status indicators
  - Training readiness score

#### FR-106: Recovery Monitoring
- **Priority:** Medium
- **Description:** Track recovery status and fatigue
- **Acceptance Criteria:**
  - Recovery time estimation
  - Fatigue accumulation tracking
  - Overtraining risk alerts
  - Recovery recommendations
  - Daily readiness score

#### FR-107: Training Zone Analysis
- **Priority:** Medium
- **Description:** Time-in-zone analysis per session
- **Acceptance Criteria:**
  - Calculate time spent in each zone
  - Zone distribution pie chart
  - Zone compliance tracking
  - Zone-based session summaries

### 2.3 Phase 3 Features (v2.0.0) - Future 📅

#### FR-201: Team/Coach Features
- **Priority:** Medium
- **Description:** Multi-athlete monitoring for coaches
- **Acceptance Criteria:**
  - Coach account with team management
  - Monitor multiple athletes simultaneously
  - Team dashboard with all athletes
  - Athlete comparison views
  - Training prescription
  - Notes and communication

#### FR-202: Advanced HRV Analysis
- **Priority:** Medium
- **Description:** Deep HRV analysis and trends
- **Acceptance Criteria:**
  - Additional HRV metrics
  - Long-term HRV trends
  - Stress/recovery balance
  - Autonomic nervous system status
  - Research-grade HRV export

---

## 3. Non-Functional Requirements

### 3.1 Performance
- **NFR-001:** Real-time HR updates < 1 second latency
- **NFR-002:** API response time < 200ms (95th percentile)
- **NFR-003:** Mobile app startup time < 3 seconds
- **NFR-004:** Support 60 concurrent sensor connections
- **NFR-005:** Handle 10,000+ sessions per user

### 3.2 Reliability
- **NFR-011:** 99.5% uptime for backend services
- **NFR-012:** Offline-first mobile app (works without internet)
- **NFR-013:** Data loss prevention with local storage
- **NFR-014:** Automatic sync retry with exponential backoff
- **NFR-015:** Session data integrity validation

### 3.3 Security
- **NFR-021:** JWT-based authentication
- **NFR-022:** HTTPS/TLS for all API communication
- **NFR-023:** Password hashing (bcrypt, 10+ rounds)
- **NFR-024:** Secure local storage (flutter_secure_storage)
- **NFR-025:** GDPR compliance for data handling
- **NFR-026:** User data isolation (no cross-user access)

### 3.4 Usability
- **NFR-031:** Material Design 3 guidelines
- **NFR-032:** Intuitive navigation (< 3 taps to any feature)
- **NFR-033:** Clear visual feedback for all actions
- **NFR-034:** Accessibility support (screen readers)
- **NFR-035:** Responsive web design (mobile, tablet, desktop)

### 3.5 Compatibility
- **NFR-041:** iOS 13+ and Android 8.0+ support
- **NFR-042:** Modern web browsers (Chrome, Firefox, Safari, Edge)
- **NFR-043:** BLE 4.0+ heart rate sensors
- **NFR-044:** Standard Bluetooth Heart Rate Service (0x180D)

### 3.6 Maintainability
- **NFR-051:** Comprehensive documentation
- **NFR-052:** 80%+ code coverage with tests
- **NFR-053:** Modular architecture
- **NFR-054:** API versioning
- **NFR-055:** Database migration support

### 3.7 Scalability
- **NFR-061:** Horizontal scaling capability
- **NFR-062:** Stateless API design
- **NFR-063:** Database indexing strategy
- **NFR-064:** CDN for static assets
- **NFR-065:** Support 10,000+ concurrent users

---

## 4. Data Requirements

### 4.1 Primary Data Entities

#### Person Profile
- Unique ID (UUID)
- Name
- Age, Gender
- Weight, Height
- Max Heart Rate
- Resting Heart Rate
- Created/Updated timestamps

#### Training Session
- Unique ID (UUID)
- Person ID (foreign key)
- Title, Notes
- Start time, End time, Duration
- Training type
- Heart rate data array (timestamp, BPM, device ID)
- Statistics (avg, max, min HR, calories)
- Sync status
- Created timestamp

#### Heart Rate Data Point
- Timestamp
- Heart Rate (BPM)
- Device ID
- Session ID (foreign key)

#### RR Interval Data (Phase 2)
- Session ID
- Timestamp
- RR interval (milliseconds)
- Data quality indicator

### 4.2 Data Storage Requirements
- **Local (Mobile):** Hive NoSQL database
- **Cloud (Backend):** Supabase (PostgreSQL)
- **Retention:** Indefinite (user-controlled deletion)
- **Backup:** Daily automated backups
- **Export:** CSV, JSON formats

---

## 5. Integration Requirements

### 5.1 External Systems
- **Bluetooth LE Sensors:** Standard HR Service (0x180D)
- **Authentication:** Supabase Auth (JWT)
- **Database:** Supabase PostgreSQL
- **Future:** Strava, Garmin Connect, Apple Health (Phase 4)

### 5.2 API Requirements
- RESTful API design
- JSON data format
- JWT authentication
- API versioning (v1, v2, etc.)
- Rate limiting (future)
- Webhook support (future)

---

## 6. Regulatory & Compliance

### 6.1 Data Privacy
- GDPR compliance (EU users)
- User data ownership
- Right to data export
- Right to deletion
- Privacy policy required
- Terms of service required

### 6.2 Health Data Regulations
- Not a medical device (disclaimer required)
- Fitness/wellness use only
- No diagnostic claims
- User assumes risk disclaimer

---

## 7. Constraints & Assumptions

### 7.1 Technical Constraints
- Flutter SDK 3.0+ required
- Node.js 16+ for backend
- iPad required for team monitoring (Polar Team Pro style)
- Internet connection for sync (not for monitoring)

### 7.2 Business Constraints
- Open-source (MIT License)
- Self-hosted option required
- No vendor lock-in
- Free for individual use

### 7.3 Assumptions
- Users have compatible BLE HR sensors
- Users have basic smartphone/computer skills
- Sensors follow Bluetooth SIG HR profile standards
- Internet available for periodic sync

---

## 8. Scientific Methodology Requirements

### 8.1 Calculation Accuracy
- All formulas must cite peer-reviewed sources
- Calculations must match published standards
- Reference implementation validation
- Test against known datasets

### 8.2 Data Quality Standards
- RR interval sampling: 250 Hz minimum
- Artifact rejection: < 5% ectopic beats
- Minimum recording duration for HRV: 5 minutes
- Data validation at capture time

### 8.3 Reference Sources Required
- NSCA CSCS textbook
- ACSM Guidelines
- Task Force HRV standards (1996)
- Peer-reviewed papers for all algorithms

**See:** [SCIENTIFIC_REFERENCES.md](./SCIENTIFIC_REFERENCES.md)

---

## 9. Requirements Traceability

| Requirement ID | Design Doc | Implementation | Test Cases | Status |
|---------------|------------|----------------|-----------|---------|
| FR-001 | ARCHITECTURE.md | BLEService | test_ble.dart | ✅ Done |
| FR-002 | ARCHITECTURE.md | DatabaseService | test_session.dart | ✅ Done |
| FR-003 | ARCHITECTURE.md | Person model | test_person.dart | ✅ Done |
| FR-004 | ARCHITECTURE.md | SyncService | test_sync.dart | ✅ Done |
| FR-005 | ARCHITECTURE.md | Web analytics | test_web.js | ✅ Done |
| FR-101 | TBD | TBD | TBD | 🔄 Planned |
| FR-102 | TBD | TBD | TBD | 🔄 Planned |

---

## 10. Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2026-01-02 | 1.0 | Initial requirements documentation | Team |
| 2026-01-02 | 1.1 | Added Phase 2 detailed requirements | Team |
| 2026-01-02 | 1.2 | Added scientific methodology requirements | Team |

---

## 11. Approval

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Product Owner | [TBD] | | |
| Technical Lead | [TBD] | | |
| QA Lead | [TBD] | | |

---

**Next Steps:**
1. Review and approve requirements
2. Create detailed design documents
3. Prioritize Phase 2 features
4. Create implementation plan
