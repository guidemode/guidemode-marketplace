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
│   Claude Code   │────▶│  Plugin Hook │────▶│  GuideMode API   │
│   (you work)    │     │  (async, bg) │     │(store + analyse) │
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
| **TaskCompleted** | A task is marked complete | Sync at natural work boundaries |
| **SubagentStop** | A subagent finishes | Capture parallel agent work |
| **Notification** | Claude sends a notification | Sync after long-running operations |

On each hook event:

1. **Hash check** — Computes SHA256 of the transcript and asks the server if it already has this version. If unchanged, done — no data transferred.
2. **Compress & upload** — If new content exists, gzips the transcript and uploads it with git metadata (branch, commit, remote URL, project type).
3. **Trigger processing** — On `SessionEnd`, tells the server to run analysis on the completed session.

Everything is **async and non-blocking**. The plugin never prints output, never interrupts your flow, and exits cleanly on any error. You'll forget it's there.

## Quick Start

The fastest way to get going:

```bash
npx guidemode
```

This walks you through:
1. Browser-based authentication (GitHub OAuth)
2. Installing Claude Code sync hooks
3. Optionally installing the CLI globally
4. Verifying everything works

That's it. Start a Claude Code session and your sessions sync automatically. View them at [app.guidemode.dev](https://app.guidemode.dev).

### Plugin Installation (Alternative)

You can also install the plugin directly in Claude Code:

```bash
/plugin marketplace add guidemode/guidemode-marketplace
/plugin install guidemode-sync@guidemode-marketplace
```

Restart Claude Code after installation, then run `/guidemode-setup`.

## Authentication

### Browser Login (Recommended)

From your terminal:

```bash
npx guidemode
```

Or from within Claude Code:

```
/guidemode-setup
```

This starts a local OAuth flow:
1. Opens your browser to GuideMode's GitHub OAuth page
2. After authentication, redirects back to a local server (port 8765-8770)
3. Saves your API key and team info to `~/.guidemode/config.json` with `600` permissions

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
guidemode status --verbose
```

### Logout

```bash
guidemode logout
```

## Configuration

Config lives at `~/.guidemode/config.json`:

| Field | Required | Description |
|-------|----------|-------------|
| `apiKey` | Yes | GuideMode API key (starts with `gm_`) |
| `serverUrl` | Yes | GuideMode server URL |
| `tenantId` | Yes | Your team/tenant ID |
| `tenantName` | No | Display name for your team |
| `syncHooks` | No | Which hook events trigger uploads (default: all) |
| `redactBeforeUpload` | No | Redact secrets/PII before upload (default: `true`) |

### Tuning Sync Frequency

Control how often the plugin uploads by setting `syncHooks`:

```jsonc
// Default: sync on all hook events (maximum freshness)
{ "syncHooks": ["Stop", "PreCompact", "SessionEnd", "TaskCompleted", "SubagentStop", "Notification"] }

// Balanced: sync at checkpoints and session end
{ "syncHooks": ["PreCompact", "SessionEnd", "TaskCompleted"] }

// Minimal: only sync when the session ends (least network usage)
{ "syncHooks": ["SessionEnd"] }

// Real-time: sync after every response + session end
{ "syncHooks": ["Stop", "SessionEnd"] }
```

Omitting `syncHooks` enables all hooks. The hash-based deduplication means even the most aggressive setting has minimal overhead — if the transcript hasn't changed, no data is transferred.

## What Gets Uploaded

Each sync includes:

| Data | Details |
|------|---------|
| **Session transcript** | Full JSONL conversation log, gzip-compressed, **redacted** |
| **Git branch** | Current branch name |
| **Git commit** | HEAD commit hash |
| **Git remote** | Remote URL (SSH URLs normalized to HTTPS) |
| **Project type** | Auto-detected: `nodejs`, `rust`, `go`, `python`, or `generic` |
| **Session ID** | Claude Code's session identifier |
| **File hash** | SHA256 for deduplication (computed after redaction) |

Project type is detected from manifest files (`package.json` → nodejs, `Cargo.toml` → rust, `go.mod` → go, `requirements.txt`/`pyproject.toml` → python).

### Automatic Secret & PII Redaction

Session transcripts naturally contain sensitive data — API keys, tokens, emails, and home directory paths that appear in tool results, bash output, and file contents. **Before uploading, the CLI automatically scans and redacts this data.**

| Category | Examples |
|----------|----------|
| API keys & tokens | AWS, GitHub (`ghp_`), Anthropic (`sk-ant-`), OpenAI, Slack, npm, Stripe, GCP, Linear, Shopify, 1Password |
| Private keys | RSA, DSA, EC, PGP private key blocks |
| Connection strings | PostgreSQL, MongoDB, Redis URIs with credentials |
| PII | Email addresses, phone numbers |
| Local paths | Home directories (`/Users/...`, `/home/...`) |

Detected values are replaced with `[REDACTED:CATEGORY]` placeholders. Structural metadata (session IDs, timestamps, roles, models, tool names) is preserved unchanged.

Redaction is **enabled by default**. To disable, set `"redactBeforeUpload": false` in `~/.guidemode/config.json`.

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
│   └── hooks.json              # Hook event registrations (6 events)
└── skills/
    ├── guidemode-setup/
    │   └── SKILL.md            # /guidemode-setup slash command
    └── guidemode-logs/
        └── SKILL.md            # /guidemode-logs slash command
```

### Design Decisions

**CLI-powered sync.** The `guidemode` CLI handles session upload, authentication, and hook management. Install once with `npx guidemode` and everything just works.

**Async and fire-and-forget.** All hooks run with a 60-second timeout. The plugin never blocks Claude Code's response cycle.

**Silent failure.** Every error path exits cleanly. Errors are logged to `~/.guidemode/logs/plugin-upload.log` but never printed to the user's terminal. A broken plugin should be invisible, not annoying.

**Hash-based deduplication.** The server stores the last-seen hash for each session. Before uploading, the plugin asks "do you already have this version?" — if yes, it skips the upload entirely. This makes frequent hook events essentially free.

**SSH URL normalization.** Git remotes like `git@github.com:org/repo.git` are converted to `https://github.com/org/repo` for consistent matching on the server side.

## Troubleshooting

### View Logs

```bash
guidemode logs           # recent logs
guidemode logs --errors  # only errors/warnings
guidemode logs --follow  # real-time
```

Or use the slash command: `/guidemode-logs`

### Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| "No config file" in logs | Not authenticated | Run `npx guidemode` |
| "Transcript file not found" | Session too short — file cleaned up before hook | Normal, no action needed |
| "Hash check request failed" | Network issue | Automatic retry on next hook event |
| "Upload failed with HTTP 401" | API key expired or revoked | Run `guidemode login` |
| Sessions not appearing in dashboard | Plugin not installed or hooks not registered | Run `guidemode status --verbose` |

## Security

- **Automatic redaction** — Secrets (API keys, tokens, private keys, connection strings) and PII (emails, phone numbers) are detected and replaced with `[REDACTED:...]` placeholders before upload. Powered by [secretlint](https://github.com/secretlint/secretlint) (15 provider rules) and [OpenRedaction](https://github.com/sam247/openredaction) (570+ patterns). Enabled by default.
- **Credentials stored locally** — API keys live in `~/.guidemode/config.json` with `600` permissions (owner-only read/write)
- **No credentials in logs** — API keys are never written to the log file
- **OAuth via localhost** — The login flow uses a localhost callback on ports 8765-8770 with a 5-minute timeout
- **HTTPS only** — All API communication uses HTTPS
- **No background processes** — The plugin only runs when Claude Code fires a hook event. Nothing persists between sessions.
- **Transparent data** — You can inspect exactly what gets uploaded by reading the log file and the transcript JSONL

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Node.js (already required by Claude Code)
- A [GuideMode](https://app.guidemode.dev) account

## Links

- [GuideMode](https://guidemode.dev) — Product website
- [Dashboard](https://app.guidemode.dev) — View your synced sessions
- [Documentation](https://docs.guidemode.dev) — Full platform docs
- [GitHub](https://github.com/guidemode/guidemode) — Source code and issues

## License

MIT
