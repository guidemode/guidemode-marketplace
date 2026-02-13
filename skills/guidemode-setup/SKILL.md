---
name: guidemode-setup
description: Configure GuideMode session sync - login, check status, or logout
user_invocable: true
---

# GuideMode Setup

This skill helps configure GuideMode session sync for Claude Code.

## Steps

1. **Run health check** to see dependencies, config, connectivity, and recent activity:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"
   ```
   For detailed output (user info, hooks, last upload), add `-v`:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh" -v
   ```

2. **If the health check shows ALL OK**, tell the user everything is working and their sessions are syncing automatically.

3. **If not configured** (config not found), offer the user two options:

   ### Option A: Browser Login (Recommended)
   Run the OAuth login flow:
   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/scripts/login.mjs"
   ```
   This opens a browser for GitHub authentication and saves credentials automatically.

   For a custom server URL:
   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/scripts/login.mjs" --server=https://your-server.example.com
   ```

   ### Option B: Manual API Key (Headless/SSH environments)
   If browser login is not possible:
   1. Go to your GuideMode dashboard > Settings > API Keys
   2. Generate a new key
   3. Create `~/.guidemode/config.json` with:
      ```json
      {
        "apiKey": "gm_your_key_here",
        "serverUrl": "https://app.guidemode.dev",
        "tenantId": "your-tenant-id",
        "tenantName": "Your Team"
      }
      ```
   4. Set file permissions: `chmod 600 ~/.guidemode/config.json`

4. **If issues are found** (dependency missing, auth failure, etc.), help the user resolve them based on the health check output.

5. **To logout**, run:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/logout.sh"
   ```

## How It Works

Once configured, the plugin automatically uploads Claude Code session transcripts to GuideMode. By default, uploads trigger on three hooks:

- **Stop** - after each Claude response (near-real-time sync)
- **PreCompact** - before context compaction (natural checkpoint)
- **SessionEnd** - when the session terminates (final upload)

Uploads run in the background and never block your workflow. Sessions are deduplicated by file hash, so redundant uploads are skipped instantly.

### Customizing Sync Hooks

To control which events trigger uploads, add `syncHooks` to `~/.guidemode/config.json`:

```json
{
  "apiKey": "gm_...",
  "serverUrl": "https://app.guidemode.dev",
  "syncHooks": ["Stop", "PreCompact", "SessionEnd"]
}
```

Available hooks: `Stop`, `PreCompact`, `SessionEnd`. Omit `syncHooks` to use all three (default).

For example, to only sync at session end (less frequent, like the desktop app):
```json
{
  "syncHooks": ["SessionEnd"]
}
```

### Logs

Upload logs are stored at `~/.guidemode/logs/plugin-upload.log`.
