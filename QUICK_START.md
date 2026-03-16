# Quick Start Guide

Get the Linglong HR Monitor platform up and running in minutes.

## Prerequisites Check

Before starting, ensure you have:

- [ ] **Node.js 16+** installed - Run `node --version`
- [ ] **npm** or **yarn** installed - Run `npm --version`
- [ ] **MongoDB** installed or access to MongoDB Atlas
- [ ] **Flutter 3.0+** (optional, for mobile development) - Run `flutter --version`
- [ ] **Git** installed - Run `git --version`

## Quick Setup (Development)

### 1. Clone the Repository

```bash
git clone https://github.com/kongmu511/linglong.git
cd linglong
```

### 2. Backend Setup (5 minutes)

```bash
# Navigate to backend
cd backend

# Install dependencies
npm install

# Create environment file
cp .env.example .env

# Edit .env file with your MongoDB URI
# For local MongoDB: mongodb://localhost:27017/linglong_hr_monitor
# For MongoDB Atlas: mongodb+srv://username:password@cluster.mongodb.net/linglong_hr_monitor

# Start the server
npm start
```

Backend will be running at `http://localhost:3000`

Test it: `curl http://localhost:3000/api/health`

### 3. Web App Setup (3 minutes)

Open a new terminal:

```bash
# Navigate to web app
cd web_app

# Install dependencies
npm install

# Start development server
npm run dev
```

Web app will be running at `http://localhost:5173`

### 4. Create a Test Account

1. Open `http://localhost:5173` in your browser
2. Click "Register"
3. Create an account with:
   - Name: Test User
   - Email: test@example.com
   - Password: test123

You're now logged in and can explore the dashboard!

## Mobile App Setup (Optional)

If you want to run the mobile app:

```bash
# Navigate to mobile app
cd mobile_app

# Install Flutter dependencies
flutter pub get

# Run on Android/iOS
flutter run
```

**Note**: You'll need to update the API URL in `lib/services/sync_service.dart` to point to your backend server (use your computer's IP address, not localhost, for mobile device testing).

## Testing the Platform

### Test Backend API

1. Register a user:
```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "test123",
    "name": "Test User"
  }'
```

2. Save the token from the response

3. Create a person profile:
```bash
curl -X POST http://localhost:3000/api/persons \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "id": "test-person-1",
    "name": "John Doe",
    "age": 30,
    "gender": "male",
    "weight": 75,
    "height": 180
  }'
```

### Test Web App

1. Log in with your test account
2. Go to Profile and fill in your information
3. View Dashboard - it should show "No training sessions yet"
4. Explore the interface

### Test Mobile App

1. Start the app on your device/emulator
2. Go to Profile tab and create your profile
3. Go to Dashboard tab
4. Tap the Bluetooth icon to scan for heart rate sensors
5. Connect a sensor (or use the app without sensors for testing)
6. Tap "Start Training" to record a session

## Common Issues

### Backend won't start

**Issue**: MongoDB connection error

**Solution**: 
- Make sure MongoDB is running: `sudo systemctl start mongod` (Linux) or check MongoDB service on Windows/Mac
- Check your `.env` file has correct MONGODB_URI
- For Atlas: Ensure IP whitelist is configured

### Web app API errors

**Issue**: CORS errors or API not reachable

**Solution**:
- Ensure backend is running on port 3000
- Check browser console for specific error
- Verify proxy configuration in `vite.config.js`

### Mobile app can't connect to backend

**Issue**: Network connection errors

**Solution**:
- Use your computer's IP address, not `localhost`
- Ensure your phone/emulator is on the same network
- Update `defaultBaseUrl` in `lib/services/sync_service.dart`
- Example: `http://192.168.1.100:3000/api`

### Flutter build errors

**Issue**: Dependency conflicts

**Solution**:
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

## Next Steps

### For Users
- Create your profile with accurate information
- Connect a Bluetooth heart rate sensor
- Record your first training session
- View your training history and statistics

### For Developers
- Read the [ARCHITECTURE.md](docs/ARCHITECTURE.md) to understand the system
- Check [DEPLOYMENT.md](docs/DEPLOYMENT.md) for production setup
- Review [ROADMAP.md](docs/ROADMAP.md) for future features
- Contribute by submitting issues or pull requests

## Development Workflow

### Making Changes

1. Create a new branch:
```bash
git checkout -b feature/your-feature-name
```

2. Make your changes

3. Test your changes:
```bash
# Backend
cd backend && npm test

# Web app
cd web_app && npm run build

# Mobile app
cd mobile_app && flutter test
```

4. Commit and push:
```bash
git add .
git commit -m "Description of changes"
git push origin feature/your-feature-name
```

5. Create a pull request

### Hot Reload

- **Backend**: Use `npm run dev` for auto-restart on changes (requires nodemon)
- **Web App**: Vite provides instant HMR
- **Mobile App**: Flutter hot reload with `r` in terminal or IDE button

## Useful Commands

### Backend
```bash
npm start          # Start server
npm run dev        # Start with auto-reload
npm test           # Run tests
```

### Web App
```bash
npm run dev        # Development server
npm run build      # Production build
npm run preview    # Preview production build
```

### Mobile App
```bash
flutter run                    # Run app
flutter build apk              # Build Android APK
flutter build ios              # Build iOS app
flutter test                   # Run tests
flutter pub run build_runner build  # Generate code
```

## Database Management

### View Data in MongoDB

Using MongoDB Compass (GUI):
1. Download from https://www.mongodb.com/products/compass
2. Connect to your MongoDB instance
3. Browse collections: users, persons, trainingsessions

Using mongo shell:
```bash
mongosh
use linglong_hr_monitor
db.users.find()
db.persons.find()
db.trainingsessions.find()
```

### Reset Database

```bash
mongosh
use linglong_hr_monitor
db.dropDatabase()
```

## Getting Help

- **Documentation**: Check the `docs/` folder
- **Issues**: Open an issue on GitHub
- **API Docs**: See README.md API Documentation section
- **Examples**: Check the test files in each project

## Resources

### Official Documentation
- [Flutter Docs](https://flutter.dev/docs)
- [React Docs](https://react.dev)
- [Express.js Docs](https://expressjs.com)
- [MongoDB Docs](https://docs.mongodb.com)

### Libraries Used
- [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) - BLE connectivity
- [Hive](https://pub.dev/packages/hive) - Local database
- [Recharts](https://recharts.org) - Web charts
- [fl_chart](https://pub.dev/packages/fl_chart) - Mobile charts

## Tips for Success

1. **Start with the web app** - It's the easiest to get running and test
2. **Use MongoDB Atlas** - Free tier is perfect for development
3. **Test the API** - Use Postman or curl to test endpoints
4. **Keep backend running** - Don't close the terminal with `npm start`
5. **Check logs** - Look at console output for errors
6. **Use developer tools** - Browser DevTools and Flutter DevTools are your friends

## Performance Tips

- Use `npm run dev` in backend for faster development
- Use React DevTools to debug web app
- Use Flutter DevTools to profile mobile app
- Keep an eye on MongoDB query performance
- Use indexes for frequently queried fields

## Security Notes for Development

⚠️ **Never commit**:
- `.env` files with real credentials
- API keys or secrets
- Database passwords
- JWT secrets

The `.gitignore` file is configured to prevent this, but always double-check before committing!

## Ready to Deploy?

Once you've tested everything locally, check out [DEPLOYMENT.md](docs/DEPLOYMENT.md) for production deployment instructions.

---

**Need help?** Open an issue on GitHub or check existing issues for solutions.

**Found a bug?** Please report it with:
- What you were trying to do
- What happened instead
- Steps to reproduce
- Your environment (OS, Node version, etc.)

Happy coding! 🚀
