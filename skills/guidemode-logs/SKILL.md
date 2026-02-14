---
name: guidemode-logs
description: Show recent GuideMode sync logs - uploads, errors, and processing activity
user_invocable: true
---

# GuideMode Logs

Show recent activity from the GuideMode sync hook log.

## Steps

1. **Show recent logs**:
   ```bash
   guidemode logs
   ```

2. **Show only errors and warnings**:
   ```bash
   guidemode logs --errors
   ```

3. **Show more lines**:
   ```bash
   guidemode logs --lines 100
   ```

4. **Follow the log in real-time**:
   ```bash
   guidemode logs --follow
   ```

## After viewing logs

**Summarize what you see** for the user:
- How many uploads succeeded vs failed
- How many were skipped (hash match / unchanged)
- Any errors or warnings
- When the last activity was

## Log Format

Each line follows this format:
```
[timestamp] LEVEL: [HookEvent] Message
```

- **INFO** - Successful operations (uploads, hash matches, processing triggers)
- **WARN** - Non-fatal issues (processing trigger failed, unexpected HTTP status)
- **ERROR** - Failures (missing config, upload failed, parse errors)
