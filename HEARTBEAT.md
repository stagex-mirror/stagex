# HEARTBEAT.md

## Active Heartbeat Tasks

### Session Recovery (every 30 min)
- **Cron job:** `session-heartbeat` (ID: d7b3324c-7d67-4ef4-9ae2-5fe1ff035717)
- **What it does:** Checks all active sessions for incomplete tasks where the agent ended its turn prematurely
- **Action:** Sends resumption messages to sessions with in-progress work
- **Runs:** Every 30 minutes on an isolated session
- **Skips:** Sessions active in last 5 min, completed tasks, greeting-only sessions

---
*Add new heartbeat tasks below as needed.*
