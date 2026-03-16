# Deployment Guide

This guide covers deploying the Linglong HR Monitor platform to production.

## Prerequisites

- Domain name configured
- SSL certificate
- MongoDB instance (Atlas or self-hosted)
- Cloud hosting account (AWS, DigitalOcean, etc.)

## Backend Deployment

### Option 1: Cloud VM (Ubuntu)

#### 1. Server Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Install PM2 globally
sudo npm install -g pm2

# Install Nginx
sudo apt install -y nginx

# Install certbot for SSL
sudo apt install -y certbot python3-certbot-nginx
```

#### 2. Deploy Application

```bash
# Clone repository
git clone https://github.com/kongmu511/linglong.git
cd linglong/backend

# Install dependencies
npm install --production

# Create .env file
nano .env
```

Add production configuration:
```env
PORT=3000
NODE_ENV=production
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/linglong_hr_monitor
JWT_SECRET=your-secure-random-secret-key-here
JWT_EXPIRE=30d
```

#### 3. Configure PM2

Create `ecosystem.config.js`:
```javascript
module.exports = {
  apps: [{
    name: 'linglong-api',
    script: 'src/server.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production'
    }
  }]
}
```

Start the application:
```bash
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

#### 4. Configure Nginx

Create `/etc/nginx/sites-available/linglong`:
```nginx
server {
    listen 80;
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable site:
```bash
sudo ln -s /etc/nginx/sites-available/linglong /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

#### 5. Configure SSL

```bash
sudo certbot --nginx -d api.yourdomain.com
```

### Option 2: Docker Deployment

Create `backend/Dockerfile`:
```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --production

COPY . .

EXPOSE 3000

CMD ["node", "src/server.js"]
```

Create `docker-compose.yml`:
```yaml
version: '3.8'

services:
  api:
    build: ./backend
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - MONGODB_URI=${MONGODB_URI}
      - JWT_SECRET=${JWT_SECRET}
    restart: unless-stopped

  mongodb:
    image: mongo:6
    ports:
      - "27017:27017"
    volumes:
      - mongodb_data:/data/db
    restart: unless-stopped

volumes:
  mongodb_data:
```

Deploy:
```bash
docker-compose up -d
```

## Web Application Deployment

### Option 1: Vercel (Recommended)

1. Install Vercel CLI:
```bash
npm install -g vercel
```

2. Navigate to web app:
```bash
cd web_app
```

3. Deploy:
```bash
vercel --prod
```

### Option 2: Netlify

1. Build the app:
```bash
cd web_app
npm run build
```

2. Deploy via Netlify CLI:
```bash
npm install -g netlify-cli
netlify deploy --prod --dir=dist
```

### Option 3: Static Hosting (Nginx)

1. Build the app:
```bash
cd web_app
npm run build
```

2. Copy to server:
```bash
scp -r dist/* user@server:/var/www/linglong/
```

3. Configure Nginx:
```nginx
server {
    listen 80;
    server_name app.yourdomain.com;

    root /var/www/linglong;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

4. Enable SSL:
```bash
sudo certbot --nginx -d app.yourdomain.com
```

## Mobile Application Deployment

### Android (Google Play Store)

1. Update `mobile_app/android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        applicationId "com.linglong.hr_monitor"
        versionCode 1
        versionName "1.0.0"
    }

    signingConfigs {
        release {
            storeFile file("path/to/keystore.jks")
            storePassword System.getenv("KEYSTORE_PASSWORD")
            keyAlias System.getenv("KEY_ALIAS")
            keyPassword System.getenv("KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

2. Build release APK:
```bash
cd mobile_app
flutter build apk --release
```

3. Build App Bundle (recommended):
```bash
flutter build appbundle --release
```

4. Upload to Google Play Console

### iOS (Apple App Store)

1. Update production API URL in `lib/services/sync_service.dart`

2. Configure Xcode:
- Open `ios/Runner.xcworkspace`
- Update Bundle Identifier
- Configure signing certificates
- Set version and build number

3. Build for release:
```bash
flutter build ios --release
```

4. Archive and upload via Xcode or Transporter

## Database Setup

### MongoDB Atlas (Recommended)

1. Create account at https://www.mongodb.com/cloud/atlas

2. Create a cluster:
   - Select region
   - Choose tier (M0 free tier for testing)

3. Configure network access:
   - Add IP whitelist (or 0.0.0.0/0 for testing)

4. Create database user:
   - Username and password
   - Read and write permissions

5. Get connection string:
   - Update backend `.env` with connection string

### Self-Hosted MongoDB

1. Install MongoDB:
```bash
# Ubuntu
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
sudo apt update
sudo apt install -y mongodb-org
```

2. Configure MongoDB:
```bash
sudo nano /etc/mongod.conf
```

Update:
```yaml
net:
  port: 27017
  bindIp: 127.0.0.1

security:
  authorization: enabled
```

3. Create admin user:
```bash
mongosh
use admin
db.createUser({
  user: "admin",
  pwd: "secure_password",
  roles: ["userAdminAnyDatabase"]
})
```

4. Create application database and user:
```javascript
use linglong_hr_monitor
db.createUser({
  user: "linglong_user",
  pwd: "secure_password",
  roles: [{ role: "readWrite", db: "linglong_hr_monitor" }]
})
```

5. Start MongoDB:
```bash
sudo systemctl start mongod
sudo systemctl enable mongod
```

## Environment Variables

### Backend Production Variables
```env
PORT=3000
NODE_ENV=production
MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/linglong_hr_monitor?retryWrites=true&w=majority
JWT_SECRET=generate-secure-random-key-minimum-32-characters
JWT_EXPIRE=30d
```

### Generate Secure JWT Secret
```bash
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

## SSL/TLS Configuration

### Let's Encrypt (Free SSL)

1. Install Certbot:
```bash
sudo apt install certbot python3-certbot-nginx
```

2. Obtain certificate:
```bash
sudo certbot --nginx -d api.yourdomain.com -d app.yourdomain.com
```

3. Auto-renewal:
```bash
sudo certbot renew --dry-run
```

Certbot automatically sets up a cron job for renewal.

## Monitoring and Logging

### Backend Logging

1. Install Winston (already in dependencies)

2. Configure logging in `src/config/logger.js`

3. PM2 logs:
```bash
pm2 logs linglong-api
pm2 logs --err  # Error logs only
```

### Database Monitoring

MongoDB Atlas provides built-in monitoring.

For self-hosted:
```bash
# Install MongoDB monitoring tools
sudo apt install mongodb-clients

# Monitor in real-time
mongosh --eval "db.serverStatus()"
```

### Application Monitoring

1. **New Relic**: Add agent to backend
2. **Sentry**: Error tracking for all platforms
3. **Google Analytics**: Web and mobile analytics

## Backup Strategy

### MongoDB Backup

Automated backups with mongodump:
```bash
# Create backup script
cat > /opt/scripts/mongo-backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/mongodb"
mkdir -p $BACKUP_DIR

mongodump --uri="mongodb://user:pass@localhost:27017/linglong_hr_monitor" --out=$BACKUP_DIR/$DATE

# Keep only last 30 days
find $BACKUP_DIR -type d -mtime +30 -exec rm -rf {} +
EOF

chmod +x /opt/scripts/mongo-backup.sh
```

Add to crontab:
```bash
crontab -e
# Add line:
0 2 * * * /opt/scripts/mongo-backup.sh
```

### Application Backup

Keep code in Git repository with regular commits and tags for releases.

## Security Checklist

- [ ] Change all default passwords
- [ ] Generate strong JWT secret
- [ ] Enable HTTPS/SSL everywhere
- [ ] Configure firewall (ufw on Ubuntu)
- [ ] Set up MongoDB authentication
- [ ] Restrict MongoDB network access
- [ ] Enable rate limiting on API
- [ ] Regular security updates
- [ ] Use environment variables for secrets
- [ ] Configure CORS properly
- [ ] Set up monitoring and alerts

## Performance Optimization

1. **Enable Gzip compression** in Nginx:
```nginx
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
```

2. **Add caching headers**:
```nginx
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

3. **Database indexes**:
```javascript
// Run in MongoDB shell
db.trainingSessions.createIndex({ userId: 1, startTime: -1 })
db.persons.createIndex({ userId: 1 })
db.users.createIndex({ email: 1 })
```

## Troubleshooting

### Backend Issues

Check logs:
```bash
pm2 logs linglong-api
journalctl -u nginx -f
```

Restart services:
```bash
pm2 restart linglong-api
sudo systemctl restart nginx
```

### Database Connection Issues

Test connection:
```bash
mongosh "mongodb+srv://cluster.mongodb.net/linglong_hr_monitor" --username user
```

Check firewall:
```bash
sudo ufw status
```

### Mobile App Issues

Update API URL in:
- `mobile_app/lib/services/sync_service.dart`

Rebuild app after changes.

## Rollback Procedure

1. Keep previous version tagged in Git
2. PM2 rollback:
```bash
pm2 stop linglong-api
git checkout previous-tag
npm install
pm2 start linglong-api
```

3. Database: Restore from backup if needed

## Updates and Maintenance

### Updating Backend

```bash
cd linglong/backend
git pull origin main
npm install
pm2 restart linglong-api
```

### Updating Web App

```bash
cd linglong/web_app
git pull origin main
npm install
npm run build
# Copy to hosting or redeploy
```

### Updating Mobile App

1. Update version in `pubspec.yaml`
2. Build new release
3. Submit to app stores

## Support and Documentation

- Backend API docs: https://api.yourdomain.com/api/health
- Web dashboard: https://app.yourdomain.com
- Mobile app: Google Play Store / Apple App Store

For issues, check logs first, then consult this guide or open an issue on GitHub.
