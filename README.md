<p align="center">
  <a href="https://guidemode.dev">
    <img src="https://app.guidemode.dev/logo-colored.png" alt="GuideMode" width="50" />
  </a>
</p>

<h3 align="center">Guidemode Session Sync for Claude Code</h3>

<p align="center">
  Every Claude Code session, captured and analyzed — automatically.
</p>

<p align="center">
  <a href="https://guidemode.dev">Website</a> &middot;
  <a href="https://app.guidemode.dev">Dashboard</a> &middot;
  <a href="https://docs.guidemode.dev">Docs</a> &middot;
  <a href="https://github.com/guidemode/guidemode">GitHub</a>
</p>

---

## Why GuideMode?

You're spending hours in Claude Code every day. But once a session ends, the context disappears. What did you build? How long did it take? What patterns work best for your team?

**GuideMode captures your Claude Code sessions and turns them into actionable insights:**

- **Session History** — Browse, search, and replay past sessions across your entire team
- **AI-Powered Analysis** — Automatic summaries, metrics extraction, and pattern detection
- **Team Visibility** — See what everyone is building, spot blockers early, share effective prompting patterns
- **Project Context** — Sessions are linked to git repos, branches, and commits automatically
- **Zero Friction** — No manual export, no copy-paste, no workflow changes

This plugin is the bridge. It runs silently in the background, syncing your sessions to GuideMode as you work.

## How It Works

```
┌─────────────────┐     ┌──────────────┐     ┌──────────────────┐
│   Claude Code    │────▶│  Plugin Hook  │────▶│  GuideMode API   │
│   (you work)     │     │  (async, bg)  │     │  (store + analyze)│
└─────────────────┘     └──────────────┘     └──────────────────┘
        │                       │                       │
   You code normally     Hash check first        AI analysis,
   Nothing changes       Skip if unchanged       metrics, search
```

The plugin registers event hooks that fire at natural checkpoints during your Claude Code session:

| Hook | When | Why |
|------|------|-----|
| **Stop** | After each Claude response | Near-real-time sync as you work |
| **PreCompact** | Before context compaction | Captures the session before the window shrinks |
| **SessionEnd** | Session terminates | Final upload — nothing is lost |

On each hook event:

1. **Hash check** — Computes SHA256 of the transcript and asks the server if it already has this version. If unchanged, done — no data transferred.
2. **Compress & upload** — If new content exists, gzips the transcript and uploads it with git metadata (branch, commit, remote URL, project type).
3. **Trigger processing** — On `SessionEnd`, tells the server to run analysis on the completed session.

Everything is **async and non-blocking**. The plugin never prints output, never interrupts your flow, and exits cleanly on any error. You'll forget it's there.

## Quick Start

### 1. Install the plugin

```bash
/plugin marketplace add guidemode/guidemode-marketplace
/plugin install guidemode-sync@guidemode-marketplace
```

Restart Claude Code after installation.

### 2. Authenticate

Run the setup skill inside Claude Code:

```
/guidemode-setup
```

This opens your browser for GitHub OAuth. After login, you select your team and credentials are saved locally.

### 3. That's it

Start a Claude Code session. The plugin syncs automatically. View your sessions at [app.guidemode.dev](https://app.guidemode.dev).

## Installation Options

### From GitHub (Recommended)

```bash
/plugin marketplace add guidemode/guidemode-marketplace
/plugin install guidemode-sync@guidemode-marketplace
```

### From a Local Path

```bash
/plugin marketplace add /path/to/guidemode-marketplace
/plugin install guidemode-sync@guidemode-marketplace
```

## Authentication

### Browser Login (Recommended)

The setup skill handles everything:

```
/guidemode-setup
```

Or run the login script directly:

```bash
node /path/to/guidemode-marketplace/scripts/login.mjs
```

This starts a local OAuth flow:
1. Opens your browser to GuideMode's GitHub OAuth page
2. After authentication, redirects back to a local server (port 8765-8770)
3. Saves your API key and team info to `~/.guidemode/config.json` with `600` permissions

**Self-hosted GuideMode:**

```bash
node /path/to/guidemode-marketplace/scripts/login.mjs --server=https://your-server.example.com
```

### Manual API Key (Headless / SSH / CI)

For environments without a browser:

1. Go to [app.guidemode.dev](https://app.guidemode.dev) > **Settings** > **API Keys**
2. Generate a new key
3. Create the config:

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
bash /path/to/guidemode-marketplace/scripts/status.sh      # quick check
bash /path/to/guidemode-marketplace/scripts/status.sh -v    # verbose (user info, hooks, last upload)
```

### Logout

```bash
bash /path/to/guidemode-marketplace/scripts/logout.sh
```

Removes `~/.guidemode/config.json`. Sessions stop syncing immediately.

## Configuration

Config lives at `~/.guidemode/config.json`:

| Field | Required | Description |
|-------|----------|-------------|
| `apiKey` | Yes | GuideMode API key (starts with `gm_`) |
| `serverUrl` | Yes | GuideMode server URL |
| `tenantId` | Yes | Your team/tenant ID |
| `tenantName` | No | Display name for your team |
| `syncHooks` | No | Which hook events trigger uploads (default: all) |

### Tuning Sync Frequency

Control how often the plugin uploads by setting `syncHooks`:

```jsonc
// Default: sync on every hook event (maximum freshness)
{ "syncHooks": ["Stop", "PreCompact", "SessionEnd"] }

// Balanced: sync at checkpoints and session end
{ "syncHooks": ["PreCompact", "SessionEnd"] }

// Minimal: only sync when the session ends (least network usage)
{ "syncHooks": ["SessionEnd"] }

// Real-time: sync after every response + session end
{ "syncHooks": ["Stop", "SessionEnd"] }
```

Omitting `syncHooks` enables all three hooks. The hash-based deduplication means even the most aggressive setting has minimal overhead — if the transcript hasn't changed, no data is transferred.

## What Gets Uploaded

Each sync includes:

| Data | Details |
|------|---------|
| **Session transcript** | Full JSONL conversation log, gzip-compressed |
| **Git branch** | Current branch name |
| **Git commit** | HEAD commit hash |
| **Git remote** | Remote URL (SSH URLs normalized to HTTPS) |
| **Project type** | Auto-detected: `nodejs`, `rust`, `go`, `python`, or `generic` |
| **Session ID** | Claude Code's session identifier |
| **File hash** | SHA256 for deduplication |

Project type is detected from manifest files (`package.json` → nodejs, `Cargo.toml` → rust, `go.mod` → go, `requirements.txt`/`pyproject.toml` → python).

## Slash Commands

| Command | What it does |
|---------|-------------|
| `/guidemode-setup` | Configure authentication, check status, customize hooks |
| `/guidemode-logs` | View recent sync activity — uploads, errors, processing |

## Architecture

```
guidemode-marketplace/
├── .claude-plugin/
│   ├── marketplace.json        # Marketplace manifest (owner, plugin list)
│   └── plugin.json             # Plugin metadata (name, version, keywords)
├── hooks/
│   ├── hooks.json              # Hook event registrations (Stop, PreCompact, SessionEnd)
│   └── sync.sh                 # Core upload script (bash + curl + node)
├── scripts/
│   ├── login.mjs               # OAuth login flow (zero NPM dependencies)
│   ├── logout.sh               # Remove stored credentials
│   └── status.sh               # Health check & connectivity verification
└── skills/
    ├── guidemode-setup/
    │   └── SKILL.md            # /guidemode-setup slash command
    └── guidemode-logs/
        └── SKILL.md            # /guidemode-logs slash command
```

### Design Decisions

**Zero NPM dependencies.** The Node.js scripts (`login.mjs`) use only built-in modules — `http`, `fs`, `crypto`, `child_process`, `os`, `path`, `url`. No `node_modules`, no install step, no supply chain risk.

**Bash for the hot path.** The sync hook (`sync.sh`) is pure bash + curl + node (for JSON parsing only). It starts fast, runs fast, and has no startup overhead from module loading.

**Async and fire-and-forget.** All hooks run with `"async": true` and a 60-second timeout. The plugin never blocks Claude Code's response cycle.

**Silent failure.** Every error path exits with code 0. Errors are logged to `~/.guidemode/logs/plugin-upload.log` but never printed to the user's terminal. A broken plugin should be invisible, not annoying.

**Hash-based deduplication.** The server stores the last-seen hash for each session. Before uploading, the plugin asks "do you already have this version?" — if yes, it skips the upload entirely. This makes frequent hook events essentially free.

**SSH URL normalization.** Git remotes like `git@github.com:org/repo.git` are converted to `https://github.com/org/repo` for consistent matching on the server side.

## Troubleshooting

### View Logs

All activity is logged to `~/.guidemode/logs/plugin-upload.log`:

```
[2026-02-13T06:25:02Z] INFO: [Stop] Processing session abc-123 from /path/to/transcript.jsonl
[2026-02-13T06:25:03Z] INFO: [Stop] Session abc-123 unchanged (hash match) - skipping
[2026-02-13T06:27:19Z] INFO: [SessionEnd] Successfully uploaded session abc-123 (HTTP 200)
[2026-02-13T06:27:20Z] INFO: [SessionEnd] Triggered processing for session abc-123
```

Or use the slash command:

```
/guidemode-logs
```

### Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| "No config file" in logs | Not authenticated | Run `/guidemode-setup` |
| "Transcript file not found" | Session too short — file cleaned up before hook | Normal, no action needed |
| "Hash check request failed" | Network issue | Automatic retry on next hook event |
| "Upload failed with HTTP 401" | API key expired or revoked | Re-run `/guidemode-setup` |
| Sessions not appearing in dashboard | Plugin not installed or hooks not registered | Run `status.sh -v` to diagnose |

### Run the Health Check

The status script verifies everything is working:

```bash
bash /path/to/guidemode-marketplace/scripts/status.sh -v
```

It checks:
- All required tools are available (node, curl, gzip, base64, sha256, git)
- Config file exists and is valid JSON
- API key is accepted by the server
- No recent errors in the log file

## Security

- **Credentials stored locally** — API keys live in `~/.guidemode/config.json` with `600` permissions (owner-only read/write)
- **No credentials in logs** — API keys are never written to the log file
- **OAuth via localhost** — The login flow uses a localhost callback on ports 8765-8770 with a 5-minute timeout
- **HTTPS only** — All API communication uses HTTPS
- **No background processes** — The plugin only runs when Claude Code fires a hook event. Nothing persists between sessions.
- **Transparent data** — You can inspect exactly what gets uploaded by reading the log file and the transcript JSONL

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Node.js (already required by Claude Code)
- Standard Unix tools: `curl`, `gzip`, `base64`, `git` (present on macOS and most Linux distributions)
- A [GuideMode](https://app.guidemode.dev) account

## Links

- [GuideMode](https://guidemode.dev) — Product website
- [Dashboard](https://app.guidemode.dev) — View your synced sessions
- [Documentation](https://docs.guidemode.dev) — Full platform docs
- [GitHub](https://github.com/guidemode/guidemode) — Source code and issues

## License

MIT
