Developer quick start
=====================

Sync this repo/branch on another machine:

```bash
# make executable first time: chmod +x scripts/sync_branch.sh
./scripts/sync_branch.sh copilot/build-heartrate-sensor-app 5d45926
```

Notes:
- The script updates `origin` to `https://github.com/zhaojia511/linglong.git`
- It fetches, checks out the target branch, fast-forwards only, and verifies the expected commit if provided
- It stops on a dirty working tree unless you set `ALLOW_DIRTY=1`

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
