
# Linglong Web App

## Local Development

```bash
cd web_app
npm install
npm run dev
# Open your deployed Cloudflare Pages URL
```

## Build for Production

```bash
npm run build
npm run preview
# Open the preview URL (your deployed Cloudflare Pages URL)
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
npm run storybook # Open Storybook at http://localhost:6006 (local only)
```

## CI/CD

GitHub Actions runs lint, test, and build on push/PR to main/develop.

---
