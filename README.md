# Linglong Heart Rate Monitor Platform

A comprehensive heart rate monitoring platform for sports load analysis, inspired by systems like Kubios and Polar Team Pro. The platform consists of three main components:

1. **Mobile Application** (Flutter) - Connect to BLE heart rate sensors and record training sessions
2. **Backend Server** (Node.js/Express) - Data storage and API
3. **Web Application** (React) - Historical data analysis and visualization

## Features

### Mobile Application
- ✅ BLE (Bluetooth Low Energy) connectivity for heart rate sensors
- ✅ Real-time heart rate display from multiple sensors
- ✅ Training session recording with live HR tracking
- ✅ Local data storage using Hive
- ✅ Person profile management
- ✅ Automatic calorie calculation
- ✅ Backend synchronization
- ✅ Material Design UI with charts

### Backend Server
- ✅ RESTful API with Express.js
- ✅ MongoDB database for data persistence
- ✅ User authentication with JWT
- ✅ Training session management
- ✅ Person profile management
- ✅ Statistics and analytics endpoints
- ✅ CORS enabled for web app

### Web Application
- ✅ User authentication (login/register)
- ✅ Dashboard with training statistics
- ✅ Training session history
- ✅ Detailed session view with HR charts
- ✅ Date range filtering
- ✅ Responsive design
- ✅ Interactive heart rate visualizations

## Architecture

```
┌─────────────────────┐
│  Mobile App         │
│  (Flutter)          │
│  - BLE Scanning     │
│  - HR Monitoring    │
│  - Local Storage    │
└──────────┬──────────┘
           │
           │ HTTP/REST API
           │
┌──────────▼──────────┐      ┌─────────────────┐
│  Backend Server     │◄─────┤  MongoDB        │
│  (Node.js/Express)  │      │  Database       │
│  - Authentication   │      └─────────────────┘
│  - Session Mgmt     │
│  - Data Analytics   │
└──────────┬──────────┘
           │
           │ HTTP/REST API
           │
┌──────────▼──────────┐
│  Web Application    │
│  (React + Vite)     │
│  - Dashboard        │
│  - Analytics        │
│  - Visualizations   │
└─────────────────────┘
```

## Technology Stack

### Mobile App
- **Framework**: Flutter 3.0+
- **State Management**: Provider
- **Database**: Hive (local NoSQL)
- **BLE**: flutter_blue_plus
- **Charts**: fl_chart, syncfusion_flutter_charts
- **HTTP**: dio, http

### Backend
- **Runtime**: Node.js
- **Framework**: Express.js
- **Database**: MongoDB with Mongoose ODM
- **Authentication**: JWT (jsonwebtoken)
- **Security**: bcryptjs for password hashing
- **Validation**: express-validator

### Web App
- **Framework**: React 18
- **Build Tool**: Vite
- **Routing**: React Router v6
- **HTTP Client**: Axios
- **Charts**: Recharts
- **Date Utilities**: date-fns

## Getting Started

### Prerequisites
- Node.js 16+ and npm
- MongoDB 5.0+
- Flutter 3.0+ (for mobile app)
- Android Studio or Xcode (for mobile app)

### Backend Setup

1. Navigate to the backend directory:
```bash
cd backend
```

2. Install dependencies:
```bash
npm install
```

3. Create `.env` file:
```bash
cp .env.example .env
```

4. Edit `.env` with your configuration:
```
PORT=3000
NODE_ENV=development
MONGODB_URI=mongodb://localhost:27017/linglong_hr_monitor
JWT_SECRET=your-secret-key-change-this-in-production
JWT_EXPIRE=30d
```

5. Start MongoDB:
```bash
# Using Docker
docker run -d -p 27017:27017 --name mongodb mongo:latest

# Or use your local MongoDB installation
mongod
```

6. Start the server:
```bash
npm start

# For development with auto-reload
npm run dev
```

The API will be available at `http://localhost:3000/api`

### Web Application Setup

1. Navigate to the web app directory:
```bash
cd web_app
```

2. Install dependencies:
```bash
npm install
```

3. Start the development server:
```bash
npm run dev
```

The web app will be available at `http://localhost:5173`

### Mobile Application Setup

1. Navigate to the mobile app directory:
```bash
cd mobile_app
```

2. Install Flutter dependencies:
```bash
flutter pub get
```

3. Generate code for Hive adapters:
```bash
flutter pub run build_runner build
```

4. Update the backend URL in `lib/services/sync_service.dart`:
```dart
static const String defaultBaseUrl = 'http://YOUR_SERVER_IP:3000/api';
```

5. Run the app:
```bash
# For Android
flutter run

# For iOS
flutter run --device-id=YOUR_IOS_DEVICE_ID
```

## API Documentation

### Authentication Endpoints

#### Register
```
POST /api/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123",
  "name": "John Doe"
}
```

#### Login
```
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

### Person Endpoints

#### Create/Update Person
```
POST /api/persons
Authorization: Bearer {token}
Content-Type: application/json

{
  "id": "uuid",
  "name": "John Doe",
  "age": 30,
  "gender": "male",
  "weight": 75.0,
  "height": 180.0,
  "maxHeartRate": 190,
  "restingHeartRate": 60
}
```

#### Get All Persons
```
GET /api/persons
Authorization: Bearer {token}
```

### Training Session Endpoints

#### Create/Update Session
```
POST /api/sessions
Authorization: Bearer {token}
Content-Type: application/json

{
  "id": "uuid",
  "personId": "person-uuid",
  "title": "Morning Run",
  "startTime": "2024-01-01T08:00:00Z",
  "endTime": "2024-01-01T09:00:00Z",
  "duration": 3600,
  "trainingType": "running",
  "avgHeartRate": 150,
  "maxHeartRate": 180,
  "minHeartRate": 120,
  "calories": 450,
  "heartRateData": [
    {
      "timestamp": "2024-01-01T08:00:00Z",
      "heartRate": 120,
      "deviceId": "device-id"
    }
  ]
}
```

#### Get All Sessions
```
GET /api/sessions?limit=50&offset=0&startDate=2024-01-01&endDate=2024-12-31
Authorization: Bearer {token}
```

#### Get Session Statistics
```
GET /api/sessions/stats/summary?startDate=2024-01-01&endDate=2024-12-31
Authorization: Bearer {token}
```

#### Delete Session
```
DELETE /api/sessions/{id}
Authorization: Bearer {token}
```

## BLE Heart Rate Sensor Support

The mobile app supports standard Bluetooth Low Energy heart rate sensors that implement the Bluetooth Heart Rate Service (UUID: 0x180D).

### Compatible Devices
- Polar H7, H9, H10
- Garmin HRM-Dual, HRM-Pro
- Wahoo TICKR
- Any BLE heart rate monitor following the Bluetooth SIG Heart Rate Profile

### Connecting Multiple Sensors
The app supports connecting multiple heart rate sensors simultaneously. The dashboard displays:
- Individual heart rate from each device
- Average heart rate across all connected devices
- Battery level (if available)
- Signal strength (RSSI)

## Development

### Mobile App Development
```bash
# Run tests
flutter test

# Build APK
flutter build apk

# Build iOS
flutter build ios
```

### Backend Development
```bash
# Run tests
npm test

# Run with nodemon for auto-reload
npm run dev
```

### Web App Development
```bash
# Development server with HMR
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

## Security Considerations

1. **Change default JWT secret** in production
2. **Use HTTPS** for all API communication
3. **Store sensitive data** in secure storage (flutter_secure_storage on mobile)
4. **Implement rate limiting** on API endpoints
5. **Validate all user inputs** on both client and server
6. **Keep dependencies updated** to patch security vulnerabilities

## Future Enhancements

- [ ] Real-time training zones analysis
- [ ] Training load and recovery metrics
- [ ] Heart rate variability (HRV) analysis
- [ ] Export training data (GPX, TCX, FIT)
- [ ] Team/coach features for monitoring multiple athletes
- [ ] Push notifications for completed syncs
- [ ] Offline mode improvements
- [ ] Integration with other fitness platforms
- [ ] Advanced analytics (VO2 max estimation, training effect)
- [ ] Social features (sharing, challenges)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License

## Support

For issues and questions, please open an issue on the GitHub repository.

## Acknowledgments

This platform is inspired by:
- **Kubios HRV** - Heart rate variability analysis
- **Polar Team Pro** - Team training monitoring
- **Polar Flow** - Training analysis platform

The architecture follows industry best practices for mobile health and fitness applications.
