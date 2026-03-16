Developer quick start
=====================

Start backend and frontend dev servers (creates logs in `logs/`):

```bash
# make executable first time: chmod +x scripts/start_dev.sh scripts/stop_dev.sh
./scripts/start_dev.sh
```

Stop dev servers:

```bash
./scripts/stop_dev.sh
```

Logs:

```bash
tail -f logs/backend.log logs/vite.log
```

Notes:
- Scripts perform a non-interactive `npm install` in `web_app` to ensure local `vite` is installed and avoid `npx` prompting to install a newer global version.
- If you prefer to run servers separately, run `cd backend && npm run dev` and `cd web_app && npm run dev`.
