# GuideMode Claude Code Plugin

A Claude Code plugin that automatically syncs session transcripts to [GuideMode](https://guidemode.dev). Lightweight alternative to the desktop app -- no local analytics, no background processes, just a hook that uploads transcripts as you work.

## How It Works

The plugin registers hooks that fire during your Claude Code session. When triggered, the hook:

1. Reads the session transcript from disk
2. Computes a SHA256 hash and checks it against the server (deduplication)
3. If the transcript has changed, gzips and uploads it to the GuideMode V2 upload endpoint
4. Extracts git metadata (branch, commit hash, remote URL, project type) and includes it in the upload

Everything runs asynchronously in the background. It never blocks your workflow, and all errors are swallowed silently (logged to `~/.guidemode/logs/plugin-upload.log`).

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Node.js (already required by Claude Code)
- A [GuideMode](https://app.guidemode.dev) account

## Installation

### From GitHub

```bash
/plugin marketplace add guidemode/guidemode-marketplace
/plugin install guidemode-sync@guidemode-marketplace
```

Restart Claude Code after installation.

### From a Local Path

```bash
/plugin marketplace add /path/to/guidemode-marketplace
/plugin install guidemode-sync@guidemode-marketplace
```

## Authentication

### Browser Login (Recommended)

Run the setup skill from within Claude Code:

```
/guidemode-setup
```

Or run the login script directly:

```bash
node /path/to/guidemode-marketplace/scripts/login.mjs
```

This opens your browser for GitHub OAuth authentication. After login, you select your team (or it auto-selects if you only have one), and credentials are saved to `~/.guidemode/config.json`.

For a self-hosted GuideMode server:

```bash
node /path/to/guidemode-marketplace/scripts/login.mjs --server=https://your-server.example.com
```

### Manual API Key (Headless / SSH Environments)

If browser login is not possible:

1. Go to your GuideMode dashboard at [app.guidemode.dev](https://app.guidemode.dev) > Settings > API Keys
2. Generate a new key
3. Create the config file:

```bash
mkdir -p ~/.guidemode
cat > ~/.guidemode/config.json << 'EOF'
{
  "apiKey": "gm_your_key_here",
  "serverUrl": "https://app.guidemode.dev",
  "tenantId": "your-tenant-id",
  "tenantName": "Your Team"
}
EOF
chmod 600 ~/.guidemode/config.json
```

### Check Status

```bash
bash /path/to/guidemode-marketplace/scripts/status.sh
```

### Logout

```bash
bash /path/to/guidemode-marketplace/scripts/logout.sh
```

This removes `~/.guidemode/config.json`. Sessions will no longer sync.

## Configuration

The config file at `~/.guidemode/config.json` supports the following fields:

| Field | Required | Description |
|-------|----------|-------------|
| `apiKey` | Yes | GuideMode API key (starts with `gm_`) |
| `serverUrl` | Yes | GuideMode server URL |
| `tenantId` | Yes | Your team/tenant ID |
| `tenantName` | No | Display name for your team |
| `syncHooks` | No | Array of hook events that trigger uploads (see below) |

### Sync Hooks

By default, the plugin syncs on three hook events:

| Hook | When it fires | Purpose |
|------|--------------|---------|
| `Stop` | After each Claude response | Near-real-time sync as you work |
| `PreCompact` | Before context window compaction | Natural checkpoint when sessions get large |
| `SessionEnd` | When the session terminates | Final upload to capture the last turn |

The hash-based deduplication means frequent hooks have minimal overhead. If the transcript has not changed since the last upload, the server returns immediately without transferring data.

To customize which hooks trigger uploads, add `syncHooks` to your config:

```json
{
  "apiKey": "gm_...",
  "serverUrl": "https://app.guidemode.dev",
  "tenantId": "...",
  "syncHooks": ["Stop", "PreCompact", "SessionEnd"]
}
```

Examples:

```json
// Only sync at session end (minimal network usage, like the desktop app)
{ "syncHooks": ["SessionEnd"] }

// Sync after each response and at session end
{ "syncHooks": ["Stop", "SessionEnd"] }
```

Omitting `syncHooks` enables all three hooks.

## What Gets Uploaded

Each upload includes:

- **Session transcript** -- the full JSONL conversation log, gzip-compressed
- **Git metadata** -- current branch, HEAD commit hash, remote URL
- **Repository info** -- working directory path, detected project type (nodejs, rust, go, python, generic)
- **Session ID and file hash** -- for deduplication and linking

The upload goes to the GuideMode V2 session endpoint, where it is stored and processed like any other session (canonical parsing, metrics extraction, AI analysis).

## Troubleshooting

### Logs

All upload activity is logged to:

```
~/.guidemode/logs/plugin-upload.log
```

Each entry is timestamped and includes the hook event that triggered it:

```
[2026-02-13T06:25:02Z] INFO: [Stop] Processing session abc-123 from /path/to/transcript.jsonl
[2026-02-13T06:25:03Z] INFO: [Stop] Session abc-123 unchanged (hash match) - skipping
[2026-02-13T06:27:19Z] INFO: [SessionEnd] Successfully uploaded session abc-123 (HTTP 200)
```

### Common Issues

**"No config file" in logs** -- Run `/guidemode-setup` or the login script to authenticate.

**"Transcript file not found"** -- The session file was already cleaned up before the hook ran. This is normal for very short sessions.

**"Hash check request failed"** -- Network issue reaching the GuideMode server. The upload will succeed on the next hook event.

**"Upload failed with HTTP 401"** -- Your API key may have expired. Re-run the login script.

## Plugin Structure

```
guidemode-marketplace/
  .claude-plugin/
    marketplace.json       # Marketplace manifest
    plugin.json            # Plugin metadata
  hooks/
    hooks.json             # Hook event registrations
    sync.sh                # Upload script (bash + curl + node)
  scripts/
    login.mjs              # OAuth login flow (Node.js, zero dependencies)
    logout.sh              # Clear stored credentials
    status.sh              # Show current auth status
  skills/
    guidemode-setup/
      SKILL.md             # /guidemode-setup slash command
```

## Links

- [GuideMode](https://guidemode.dev) -- Product website
- [GuideMode Dashboard](https://app.guidemode.dev) -- Log in to your account
- [GuideMode Documentation](https://docs.guidemode.dev) -- Full documentation

## License

MIT
