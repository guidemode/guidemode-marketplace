---
name: guidemode-setup
description: Configure GuideMode session sync - login, check status, or logout
user_invocable: true
---

# GuideMode Setup

This skill configures GuideMode session sync for Claude Code.

## Quick Start

Run the CLI (handles login, hooks, and verification):

```bash
npx guidemode
```

This will:
1. Open your browser for authentication
2. Ask if you want to install Claude Code sync hooks
3. Offer to install the CLI globally
4. Verify everything is working

## Other Commands

**Check status**:
```bash
guidemode status --verbose
```

**View logs**:
```bash
guidemode logs
```

**Re-run setup** (e.g. to fix hooks):
```bash
guidemode setup --force
```

**Logout**:
```bash
guidemode logout
```

## How It Works

Once configured, session transcripts are automatically uploaded to GuideMode on these hooks:

- **Stop** - after each Claude response
- **PreCompact** - before context compaction
- **SessionEnd** - when the session terminates
- **TaskCompleted** - when a task is marked complete
- **SubagentStop** - when a subagent finishes
- **Notification** - when Claude sends a notification

Uploads run in the background and never block your workflow. Sessions are deduplicated by file hash.

### Customizing Sync Hooks

Add `syncHooks` to `~/.guidemode/config.json`:
```json
{
  "syncHooks": ["SessionEnd"]
}
```

Available hooks: `Stop`, `PreCompact`, `SessionEnd`, `TaskCompleted`, `SubagentStop`, `Notification`. Omit to use all (default).

### Logs

View logs with `guidemode logs` or at `~/.guidemode/logs/plugin-upload.log`.
