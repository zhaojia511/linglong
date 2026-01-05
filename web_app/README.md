
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
