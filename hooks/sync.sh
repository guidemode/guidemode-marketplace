#!/usr/bin/env bash
# GuideMode Session Sync Hook
# Runs async on configurable hook events - gzips and uploads Claude Code transcripts.
# All errors exit 0 (never alarm the user) and log to file.

set -euo pipefail

CONFIG_DIR="$HOME/.guidemode"
CONFIG_FILE="$CONFIG_DIR/config.json"
LOG_DIR="$CONFIG_DIR/logs"
LOG_FILE="$LOG_DIR/plugin-upload.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

log() {
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Clean up temp files on exit
TMPFILES=()
cleanup() {
  for f in "${TMPFILES[@]}"; do
    rm -f "$f" 2>/dev/null || true
  done
}
trap cleanup EXIT

# Wrap everything so errors never propagate to the user
main() {
  # Read stdin (Claude Code passes JSON with session_id, transcript_path, cwd, hook_event_name)
  local input
  input=$(cat)

  if [ -z "$input" ]; then
    log "ERROR: No input received on stdin"
    return 0
  fi

  # Parse stdin JSON using node (guaranteed available in Claude Code environments)
  local session_id transcript_path cwd hook_event
  eval "$(node -e "
    const d = JSON.parse(process.argv[1]);
    console.log('session_id=' + JSON.stringify(d.session_id || ''));
    console.log('transcript_path=' + JSON.stringify(d.transcript_path || ''));
    console.log('cwd=' + JSON.stringify(d.cwd || ''));
    console.log('hook_event=' + JSON.stringify(d.hook_event_name || ''));
  " "$input" 2>/dev/null)" || {
    log "ERROR: Failed to parse stdin JSON"
    return 0
  }

  if [ -z "$session_id" ] || [ -z "$transcript_path" ]; then
    log "ERROR: Missing session_id or transcript_path in input"
    return 0
  fi

  # Check config exists
  if [ ! -f "$CONFIG_FILE" ]; then
    log "INFO: No config file at $CONFIG_FILE - skipping upload (run login first)"
    return 0
  fi

  # Read config and check if this hook event is enabled
  local api_key server_url hook_enabled
  eval "$(node -e "
    const fs = require('fs');
    const c = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
    const hookEvent = process.argv[2];
    const defaultHooks = ['Stop', 'PreCompact', 'SessionEnd'];
    const enabledHooks = c.syncHooks || defaultHooks;
    const isEnabled = enabledHooks.includes(hookEvent);
    console.log('api_key=' + JSON.stringify(c.apiKey || ''));
    console.log('server_url=' + JSON.stringify(c.serverUrl || ''));
    console.log('hook_enabled=' + JSON.stringify(isEnabled ? 'true' : 'false'));
  " "$CONFIG_FILE" "$hook_event" 2>/dev/null)" || {
    log "ERROR: Failed to read config file"
    return 0
  }

  if [ "$hook_enabled" = "false" ]; then
    log "INFO: Hook $hook_event not enabled in syncHooks config - skipping"
    return 0
  fi

  if [ -z "$api_key" ] || [ -z "$server_url" ]; then
    log "ERROR: Missing apiKey or serverUrl in config"
    return 0
  fi

  # Check transcript file exists
  if [ ! -f "$transcript_path" ]; then
    log "ERROR: Transcript file not found: $transcript_path"
    return 0
  fi

  log "INFO: [$hook_event] Processing session $session_id from $transcript_path"

  # Compute SHA256 hash (cross-platform)
  local file_hash
  if command -v shasum >/dev/null 2>&1; then
    file_hash=$(shasum -a 256 "$transcript_path" | cut -d' ' -f1)
  elif command -v sha256sum >/dev/null 2>&1; then
    file_hash=$(sha256sum "$transcript_path" | cut -d' ' -f1)
  else
    log "ERROR: No sha256 tool available"
    return 0
  fi

  # Check hash with server (dedup)
  local check_response check_http_code
  check_response=$(curl -sS -w "\n%{http_code}" \
    -H "Authorization: Bearer $api_key" \
    "${server_url}/api/agent-sessions/check-hash?sessionId=$(printf '%s' "$session_id" | sed 's/ /%20/g')&fileHash=$file_hash" \
    2>/dev/null) || {
    log "ERROR: Hash check request failed"
    return 0
  }

  check_http_code=$(echo "$check_response" | tail -n1)
  local check_body
  check_body=$(echo "$check_response" | sed '$d')

  if [ "$check_http_code" = "200" ]; then
    local needs_upload
    needs_upload=$(node -e "
      const d = JSON.parse(process.argv[1]);
      console.log(d.needsUpload ? 'true' : 'false');
    " "$check_body" 2>/dev/null) || needs_upload="true"

    if [ "$needs_upload" = "false" ]; then
      log "INFO: [$hook_event] Session $session_id unchanged (hash match) - skipping"
      return 0
    fi
  else
    log "WARN: Hash check returned $check_http_code - proceeding with upload"
  fi

  # Gzip and base64 encode the transcript
  local b64_file
  b64_file=$(mktemp)
  TMPFILES+=("$b64_file")

  gzip -c "$transcript_path" | base64 > "$b64_file" 2>/dev/null || {
    log "ERROR: Failed to gzip/base64 transcript"
    return 0
  }

  local file_size
  file_size=$(wc -c < "$transcript_path" | tr -d ' ')

  # Extract git metadata from cwd
  local repo_name git_remote_url git_branch latest_commit_hash detected_repo_type
  git_remote_url=""
  git_branch=""
  latest_commit_hash=""
  detected_repo_type="generic"

  if [ -n "$cwd" ] && [ -d "$cwd" ]; then
    git_remote_url=$(cd "$cwd" && git remote get-url origin 2>/dev/null) || git_remote_url=""
    # Normalize SSH URLs to HTTPS (match desktop app behavior)
    if [ -n "$git_remote_url" ]; then
      git_remote_url=$(node -e "
        const url = process.argv[1];
        if (url.startsWith('git@github.com:')) {
          console.log('https://github.com/' + url.slice('git@github.com:'.length));
        } else if (url.startsWith('ssh://git@github.com/')) {
          console.log('https://github.com/' + url.slice('ssh://git@github.com/'.length));
        } else {
          console.log(url);
        }
      " "$git_remote_url" 2>/dev/null) || true
    fi
    git_branch=$(cd "$cwd" && git rev-parse --abbrev-ref HEAD 2>/dev/null) || git_branch=""
    latest_commit_hash=$(cd "$cwd" && git rev-parse HEAD 2>/dev/null) || latest_commit_hash=""

    # Detect repository type from project files
    if [ -f "$cwd/package.json" ]; then
      detected_repo_type="nodejs"
    elif [ -f "$cwd/Cargo.toml" ]; then
      detected_repo_type="rust"
    elif [ -f "$cwd/go.mod" ]; then
      detected_repo_type="go"
    elif [ -f "$cwd/requirements.txt" ] || [ -f "$cwd/pyproject.toml" ] || [ -f "$cwd/setup.py" ]; then
      detected_repo_type="python"
    fi
  fi

  # Determine repository name
  repo_name=""
  if [ -n "$git_remote_url" ]; then
    # Extract org/repo from git URL (handles both HTTPS and SSH)
    repo_name=$(node -e "
      const url = process.argv[1];
      const m = url.match(/[:/]([^/]+\/[^/.]+?)(?:\.git)?$/);
      console.log(m ? m[1] : '');
    " "$git_remote_url" 2>/dev/null) || repo_name=""
  fi

  if [ -z "$repo_name" ] && [ -n "$cwd" ]; then
    repo_name=$(basename "$cwd")
  fi

  if [ -z "$repo_name" ]; then
    repo_name="unknown"
  fi

  # Build JSON payload via node (handles escaping correctly, reads base64 from file)
  local payload_file
  payload_file=$(mktemp)
  TMPFILES+=("$payload_file")

  node -e "
    const fs = require('fs');
    const b64Content = fs.readFileSync(process.argv[1], 'utf8').replace(/\n/g, '');
    const sessionId = process.argv[3];
    const payload = {
      provider: 'claude-code',
      repositoryName: process.argv[2],
      sessionId: sessionId,
      fileName: sessionId + '.jsonl',
      fileHash: process.argv[4],
      content: b64Content,
      contentEncoding: 'gzip',
      fileSize: Number(process.argv[5]) || undefined,
      repositoryMetadata: {
        cwd: process.argv[6] || '.',
        gitRemoteUrl: process.argv[7] || null,
        detectedRepositoryType: process.argv[10] || 'generic'
      }
    };
    if (process.argv[8]) payload.gitBranch = process.argv[8];
    if (process.argv[9]) payload.latestCommitHash = process.argv[9];
    if (process.argv[9]) payload.firstCommitHash = process.argv[9];
    fs.writeFileSync(process.argv[11], JSON.stringify(payload));
  " "$b64_file" "$repo_name" "$session_id" "$file_hash" "$file_size" "$cwd" "$git_remote_url" "$git_branch" "$latest_commit_hash" "$detected_repo_type" "$payload_file" 2>/dev/null || {
    log "ERROR: Failed to build upload payload"
    return 0
  }

  # Upload to server
  local upload_response upload_http_code
  upload_response=$(curl -sS -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    -d @"$payload_file" \
    "${server_url}/api/agent-sessions/upload-v2" \
    2>/dev/null) || {
    log "ERROR: Upload request failed"
    return 0
  }

  upload_http_code=$(echo "$upload_response" | tail -n1)
  local upload_body
  upload_body=$(echo "$upload_response" | sed '$d')

  if [ "$upload_http_code" = "200" ] || [ "$upload_http_code" = "201" ]; then
    log "INFO: [$hook_event] Successfully uploaded session $session_id (HTTP $upload_http_code)"

    # On SessionEnd, trigger server-side processing of the session
    if [ "$hook_event" = "SessionEnd" ]; then
      local process_response process_http_code
      process_response=$(curl -sS -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d '{}' \
        "${server_url}/api/session-processing/process/${session_id}" \
        2>/dev/null) || {
        log "WARN: [SessionEnd] Processing trigger failed for session $session_id"
        return 0
      }

      process_http_code=$(echo "$process_response" | tail -n1)
      if [ "$process_http_code" = "200" ] || [ "$process_http_code" = "201" ]; then
        log "INFO: [SessionEnd] Triggered processing for session $session_id"
      else
        local process_body
        process_body=$(echo "$process_response" | sed '$d')
        log "WARN: [SessionEnd] Processing trigger returned HTTP $process_http_code: $process_body"
      fi
    fi
  else
    log "ERROR: [$hook_event] Upload failed with HTTP $upload_http_code: $upload_body"
  fi
}

main "$@" || true
exit 0
