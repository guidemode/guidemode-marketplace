#!/usr/bin/env bash
# GuideMode Status & Health Check

CONFIG_DIR="$HOME/.guidemode"
CONFIG_FILE="$CONFIG_DIR/config.json"
LOG_FILE="$CONFIG_DIR/logs/plugin-upload.log"
ALL_OK=true
VERBOSE="${1:-}"  # Pass "verbose" or "-v" for detail

checks=""
details=""

check_pass() { checks="${checks} ✓ $1"; }
check_fail() { checks="${checks} ✗ $1"; details="${details}\n  ✗ $1: $2"; ALL_OK=false; }
check_warn() { details="${details}\n  ! $1: $2"; }

# ── Dependencies ──────────────────────────────────────────────
missing_deps=""
command -v node >/dev/null 2>&1 || missing_deps="${missing_deps}node "
command -v curl >/dev/null 2>&1 || missing_deps="${missing_deps}curl "
command -v gzip >/dev/null 2>&1 || missing_deps="${missing_deps}gzip "
command -v base64 >/dev/null 2>&1 || missing_deps="${missing_deps}base64 "
{ command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1; } || missing_deps="${missing_deps}sha256 "
command -v git >/dev/null 2>&1 || missing_deps="${missing_deps}git "

if [ -z "$missing_deps" ]; then
  check_pass "Dependencies"
else
  check_fail "Dependencies" "missing: $missing_deps"
fi

# ── Configuration ─────────────────────────────────────────────
if [ ! -f "$CONFIG_FILE" ]; then
  check_fail "Config" "not found — run /guidemode-setup to configure"
  printf '\033[38;5;208m>\033[38;5;34m>\033[0m%s\n' "$checks"
  printf '%b\n' "$details"
  exit 0
fi

eval "$(node -e "
  const fs = require('fs');
  try {
    const c = JSON.parse(fs.readFileSync('$CONFIG_FILE', 'utf8'));
    console.log('api_key=' + JSON.stringify(c.apiKey || ''));
    console.log('server_url=' + JSON.stringify(c.serverUrl || ''));
    console.log('tenant_name=' + JSON.stringify(c.tenantName || ''));
    console.log('username=' + JSON.stringify(c.username || c.name || ''));
    const hooks = c.syncHooks || ['Stop', 'PreCompact', 'SessionEnd'];
    console.log('sync_hooks=' + JSON.stringify(hooks.join(', ')));
  } catch (e) {
    console.log('api_key='); console.log('server_url=');
    console.log('tenant_name='); console.log('username='); console.log('sync_hooks=');
  }
" 2>/dev/null)" || { check_fail "Config" "could not parse config file"; }

if [ -n "$server_url" ] && [ -n "$api_key" ]; then
  check_pass "Config"
else
  [ -z "$server_url" ] && check_fail "Config" "server URL not configured"
  [ -z "$api_key" ] && check_fail "Config" "API key not configured"
fi

# ── Connectivity ──────────────────────────────────────────────
if [ -n "$server_url" ] && [ -n "$api_key" ]; then
  http_code=$(curl -sS -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $api_key" \
    "${server_url}/auth/session" \
    --connect-timeout 5 --max-time 10 2>/dev/null) || http_code="000"

  if [ "$http_code" = "200" ]; then
    check_pass "Server"
  elif [ "$http_code" = "401" ] || [ "$http_code" = "403" ]; then
    check_fail "Server" "API key invalid (HTTP $http_code)"
  elif [ "$http_code" = "000" ]; then
    check_fail "Server" "cannot reach $server_url"
  else
    check_fail "Server" "HTTP $http_code"
  fi
else
  check_fail "Server" "cannot test (missing config)"
fi

# ── Logs ──────────────────────────────────────────────────────
if [ -f "$LOG_FILE" ]; then
  recent_errors=$(tail -50 "$LOG_FILE" 2>/dev/null | grep -c "ERROR" || echo "0")
  if [ "$recent_errors" -gt 0 ]; then
    check_warn "Logs" "$recent_errors recent errors"
  fi
  check_pass "Logs"
else
  check_pass "Logs"
fi

# ── Output ────────────────────────────────────────────────────
printf '\033[38;5;208m>\033[38;5;34m>\033[0m%s\n' "$checks"

# Show details if issues found or verbose requested
if [ "$ALL_OK" = false ]; then
  printf '%b\n' "$details"
elif [ "$VERBOSE" = "verbose" ] || [ "$VERBOSE" = "-v" ]; then
  echo "  User: ${username:-?}@${tenant_name:-?} → $server_url"
  echo "  Hooks: $sync_hooks"
  if [ -f "$LOG_FILE" ]; then
    last_upload=$(grep -E "Successfully uploaded|Upload failed|unchanged" "$LOG_FILE" 2>/dev/null | tail -1)
    [ -n "$last_upload" ] && echo "  Last: ${last_upload##*] }"
  fi
fi

# Summary
if [ "$ALL_OK" = true ]; then
  printf '\033[32m✓ ALL OK\033[0m — Sessions are syncing to GuideMode\n'
else
  printf '\033[31m✗ ISSUES FOUND\033[0m — See above for details\n'
fi
