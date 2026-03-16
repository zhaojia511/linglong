# Linglong Heart Rate Monitor - Documentation

## Table of Contents

### User Documentation
- [Quick Start Guide](QUICK_START.md)
- [BLE Sensor Troubleshooting](USER_MANUAL_BLE_TROUBLESHOOTING.md)
- [Training Session Guide](USER_MANUAL_TRAINING.md) *(Coming Soon)*
- [Data Export & Sync](USER_MANUAL_SYNC.md) *(Coming Soon)*

### Developer Documentation
- [Architecture Overview](ARCHITECTURE.md)
- [API Reference](API_REFERENCE.md) *(Coming Soon)*
- [Development Guide](DEVELOPMENT_LOG.md)
- [Deployment Guide](DEPLOYMENT.md)

### Technical Documentation
- [Technology Stack](TECH_STACK.md)
- [Design Decisions](DESIGN_DECISIONS.md)
- [Scientific References](SCIENTIFIC_REFERENCES.md)
- [Requirements](REQUIREMENTS.md)

### Hardware Documentation
- [ESP32 Setup](../hardware/README.md)
- [Sensor Assignment](SENSOR_ATHLETE_LINKING.md)

### Project Management
- [Roadmap](ROADMAP.md)
- [Change Log](CHANGELOG.md) *(Coming Soon)*

---

## Quick Links

### For End Users
- **Getting Started**: See [QUICK_START.md](QUICK_START.md)
- **Troubleshooting**: Common issues and solutions
- **Support**: Report issues via GitHub Issues

### For Developers
- **Setup Development Environment**: See [README.dev.md](../README.dev.md)
- **Contributing**: See [CONTRIBUTING.md](CONTRIBUTING.md) *(Coming Soon)*
- **Code Documentation**: Run `flutter doc` for API docs

### For Administrators
- **Deployment**: See [DEPLOYMENT.md](DEPLOYMENT.md)
- **Database Schema**: See [supabase/schema.sql](../supabase/schema.sql)
- **Backend Setup**: See [backend/README.md](../backend/README.md) *(Coming Soon)*

---

## Documentation Generation

### Flutter/Dart API Documentation
Generate code documentation:
```bash
cd mobile_app
flutter pub global activate dartdoc
flutter pub global run dartdoc
open doc/api/index.html
```

### Node.js API Documentation (Backend)
Generate backend API docs:
```bash
cd backend
npm install -g jsdoc
jsdoc -c jsdoc.json
open docs/jsdoc/index.html
```

### React Component Documentation (Web)
Generate component docs:
```bash
cd web_app
npm install -g react-docgen
# Coming soon
```

---

## Contributing to Documentation

### Adding New Documentation
1. Create markdown file in `/docs` directory
2. Follow existing format and structure
3. Add entry to this index
4. Submit pull request

### Documentation Standards
- Use clear, concise language
- Include code examples where applicable
- Add screenshots for UI features
- Keep it up-to-date with code changes

### Building Full Documentation Site
For comprehensive documentation site with ReadTheDocs:
```bash
# Install MkDocs
pip install mkdocs mkdocs-material

# Serve locally
mkdocs serve

# Build static site
mkdocs build
```

---

**Last Updated**: January 2026
