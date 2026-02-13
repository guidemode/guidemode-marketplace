---
name: guidemode-logs
description: Show recent GuideMode sync logs - uploads, errors, and processing activity
user_invocable: true
---

# GuideMode Logs

Show recent activity from the GuideMode sync hook log.

## Steps

1. **Show the last 30 lines** of the log file:
   ```bash
   tail -30 ~/.guidemode/logs/plugin-upload.log 2>/dev/null || echo "No log file found at ~/.guidemode/logs/plugin-upload.log"
   ```

2. **Summarize what you see** for the user:
   - How many uploads succeeded vs failed
   - How many were skipped (hash match / unchanged)
   - Any errors or warnings
   - When the last activity was

3. **If the user asks for more**, show additional lines:
   ```bash
   tail -100 ~/.guidemode/logs/plugin-upload.log
   ```

4. **To show only errors and warnings**:
   ```bash
   grep -E "(ERROR|WARN)" ~/.guidemode/logs/plugin-upload.log | tail -20
   ```

## Log Format

Each line follows this format:
```
[timestamp] LEVEL: [HookEvent] Message
```

- **INFO** - Successful operations (uploads, hash matches, processing triggers)
- **WARN** - Non-fatal issues (processing trigger failed, unexpected HTTP status)
- **ERROR** - Failures (missing config, upload failed, parse errors)
