
# Linglong Web App

## Local Development

```bash
cd web_app
npm install
npm run dev
# Open http://localhost:5173
```

## Build for Production

```bash
npm run build
npm run preview
# Open the preview URL (default http://localhost:5173)
```

## Lint & Format

```bash
npm run lint      # Check code style
npm run lint:fix  # Auto-fix lint errors
npm run format    # Format code with Prettier
```

## Run Tests

```bash
npm run test      # Run unit and a11y tests
```

## Storybook (UI Components)

```bash
npm run storybook # Open Storybook at http://localhost:6006
```

## CI/CD

GitHub Actions runs lint, test, and build on push/PR to main/develop.

---

## Deployment

### Prerequisites

Create a `.env.docker` file from the example:
```bash
cp .env.docker.example .env.docker
```

Edit `.env.docker` with your Supabase credentials:
- `VITE_SUPABASE_URL` - Your Supabase project URL
- `VITE_SUPABASE_ANON_KEY` - Your Supabase anon public key
- `VITE_API_BASE_URL` - (Not used in current codebase, can leave as default)

### Option 1: Docker Compose (Recommended)

```bash
# Build and start
docker-compose up --build -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

The app will be available at http://localhost:8080.

### Option 2: Docker Build and Run

```bash
# Build the image (replace with your actual env values)
docker build \
  --build-arg VITE_SUPABASE_URL=https://your-project.supabase.co \
  --build-arg VITE_SUPABASE_ANON_KEY=your-anon-key \
  -t linglong-web .

# Run the container
docker run -d -p 8080:80 --name linglong-web --restart unless-stopped linglong-web

# View logs
docker logs -f linglong-web

# Stop
docker stop linglong-web
```

### Option 3: Deploy to Server via Image Tarball

Build locally and transfer to server without Docker Hub:

```bash
# 1. Build and save image locally
docker build \
  --build-arg VITE_SUPABASE_URL=https://your-project.supabase.co \
  --build-arg VITE_SUPABASE_ANON_KEY=your-anon-key \
  -t linglong-web .

docker save -o linglong-web.tar linglong-web

# 2. Upload to server
scp linglong-web.tar user@your-server:/path/on/server/

# 3. On server: load and run
docker load -i linglong-web.tar
docker run -d -p 8080:80 --name linglong-web --restart unless-stopped linglong-web
```

### Option 4: Static Deployment (Simplest)

Build locally and upload the `dist` folder to any static hosting:

```bash
# Build
npm run build

# Upload the `dist` folder to your server
# Serve with Nginx, Apache, or any static file server
```

Example Nginx config:
```nginx
server {
    listen 80;
    server_name your-domain.com;
    root /path/to/dist;
    index index.html;
    
    # Handle SPA client-side routing
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

---
