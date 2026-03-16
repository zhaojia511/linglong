# System Architecture

## Overview

The Linglong HR Monitor platform is designed as a three-tier application with clear separation of concerns:

1. **Presentation Layer**: Mobile app (Flutter) and Web app (React)
2. **Application Layer**: Backend API (Node.js/Express)
3. **Data Layer**: MongoDB database

## Component Details

### Mobile Application (Flutter)

#### Architecture Pattern
- **State Management**: Provider pattern for reactive state updates
- **Service Layer**: Separation of concerns with dedicated services
  - BLEService: Bluetooth communication
  - DatabaseService: Local data persistence
  - SyncService: Backend synchronization
- **Data Layer**: Hive for local NoSQL storage

#### Data Flow
```
User Action → Screen → Provider → Service → Local DB/BLE/API
                ↓
            UI Update
```

#### Key Components

**BLE Service**
- Scans for Bluetooth heart rate monitors
- Connects to multiple devices simultaneously
- Parses Heart Rate Measurement characteristic (0x2A37)
- Reads battery level when available
- Maintains connection state

**Database Service**
- Person profile CRUD operations
- Training session management
- Automatic statistics calculation (avg, max, min HR)
- Calorie estimation based on personal metrics

**Sync Service**
- JWT-based authentication
- Automatic sync of unsynced sessions
- Person profile synchronization
- Background sync capability

### Backend Server (Node.js/Express)

#### Architecture Pattern
- **RESTful API**: Standard HTTP methods and status codes
- **MVC Pattern**: Models, Routes, Controllers separation
- **Middleware**: Authentication, validation, error handling

#### Security Features
- JWT token-based authentication
- Password hashing with bcrypt
- Request validation with express-validator
- CORS configuration for web app

#### Database Schema

**User Collection**
```javascript
{
  _id: ObjectId,
  email: String (unique, indexed),
  password: String (hashed),
  name: String,
  role: String (enum: user, coach, admin),
  createdAt: Date
}
```

**Person Collection**
```javascript
{
  _id: ObjectId,
  id: String (UUID from mobile),
  userId: ObjectId (ref: User),
  name: String,
  age: Number,
  gender: String,
  weight: Number,
  height: Number,
  maxHeartRate: Number,
  restingHeartRate: Number,
  createdAt: Date,
  updatedAt: Date
}
```

**TrainingSession Collection**
```javascript
{
  _id: ObjectId,
  id: String (UUID from mobile),
  userId: ObjectId (ref: User),
  personId: String,
  title: String,
  startTime: Date,
  endTime: Date,
  duration: Number,
  distance: Number,
  avgHeartRate: Number,
  maxHeartRate: Number,
  minHeartRate: Number,
  calories: Number,
  trainingType: String,
  heartRateData: [{
    timestamp: Date,
    heartRate: Number,
    deviceId: String
  }],
  notes: String,
  createdAt: Date
}
```

#### API Endpoints Structure

```
/api
├── /auth
│   ├── POST /register
│   └── POST /login
├── /persons
│   ├── GET /
│   ├── POST /
│   └── GET /:id
└── /sessions
    ├── GET /
    ├── POST /
    ├── GET /:id
    ├── DELETE /:id
    └── GET /stats/summary
```

### Web Application (React)

#### Architecture Pattern
- **Component-Based**: Reusable UI components
- **Client-Side Routing**: React Router for SPA navigation
- **Service Layer**: Axios-based API client
- **State Management**: React hooks (useState, useEffect)

#### Pages
1. **Login**: User authentication with register option
2. **Dashboard**: Overview statistics and recent sessions
3. **Sessions**: List all training sessions with filtering
4. **SessionDetail**: Detailed view with heart rate chart

#### Data Visualization
- Recharts library for responsive charts
- Line charts for heart rate trends
- Statistics cards for key metrics
- Date-based filtering

## Data Flow

### Training Session Recording Flow

```
1. User opens mobile app
2. App scans for BLE heart rate monitors
3. User connects to one or more devices
4. Real-time HR data streams to dashboard
5. User starts recording session
   ↓
6. App records HR data points every second
7. Data stored locally in Hive
8. Session displayed in real-time chart
9. User stops recording
   ↓
10. App calculates statistics:
    - Average HR
    - Max/Min HR
    - Duration
    - Estimated calories
11. Session saved to local database
12. Sync service uploads to backend (when online)
13. Backend stores in MongoDB
14. Web app can retrieve and visualize data
```

### Authentication Flow

```
1. User registers/logs in via mobile or web app
2. Backend validates credentials
3. JWT token generated and returned
4. Token stored locally
   - Mobile: flutter_secure_storage
   - Web: localStorage
5. Token included in Authorization header for API requests
6. Backend middleware verifies token
7. Request processed if valid
```

## Scalability Considerations

### Current Design
- Single MongoDB instance
- Node.js single process
- Direct client-to-server communication

### Future Enhancements
- **Database**: MongoDB replica set for high availability
- **Backend**: Horizontal scaling with load balancer
- **Caching**: Redis for session data and statistics
- **Real-time**: WebSocket support for live updates
- **CDN**: Static asset delivery for web app
- **Queue**: Background job processing for heavy analytics

## Security Architecture

### Mobile App
- Secure storage for tokens
- Certificate pinning for API calls
- Local database encryption option
- Permission requests for Bluetooth and location

### Backend
- HTTPS only in production
- JWT with expiration
- Password hashing (bcrypt, 10 rounds)
- Input validation and sanitization
- Rate limiting on endpoints
- CORS whitelist

### Web App
- XSS protection (React default)
- CSRF token consideration
- Secure cookie options
- Content Security Policy headers

## Deployment Architecture

### Development
```
Mobile App → Local Device/Emulator
Backend → localhost:3000
Web App → localhost:5173 (Vite dev server)
Database → Local MongoDB
```

### Production
```
Mobile App → Google Play Store / Apple App Store
Backend → Cloud VM (AWS EC2, DigitalOcean, etc.)
         → Behind Nginx reverse proxy
         → PM2 process manager
Web App → Static hosting (Vercel, Netlify, S3 + CloudFront)
Database → MongoDB Atlas or self-hosted cluster
```

## Monitoring and Observability

### Recommended Tools
- **Application Monitoring**: New Relic, Datadog
- **Error Tracking**: Sentry
- **Logging**: Winston (backend), Crashlytics (mobile)
- **Analytics**: Google Analytics, Mixpanel
- **Uptime Monitoring**: UptimeRobot, Pingdom

## Performance Optimization

### Mobile App
- Lazy loading of screens
- Image caching
- Pagination for session list
- Debouncing BLE scans
- Background sync throttling

### Backend
- Database indexes on frequently queried fields
- Response pagination
- Compression middleware
- Query optimization
- Connection pooling

### Web App
- Code splitting
- Lazy loading routes
- Asset optimization
- Service worker for offline capability
- Chart data sampling for large datasets

## Backup and Recovery

### Data Backup Strategy
- Mobile: Local data synced to backend
- Backend: MongoDB daily backups
- Retention: 30 days of backups
- Recovery: Point-in-time restoration

### Disaster Recovery
- Database backup to separate region
- Infrastructure as Code (Terraform/CloudFormation)
- Documented deployment procedures
- Regular DR testing schedule
