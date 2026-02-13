#!/usr/bin/env bash
# GuideMode status - shows current authentication status

CONFIG_FILE="$HOME/.guidemode/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Not configured. Run 'node scripts/login.mjs' to authenticate."
  exit 0
fi

node -e "
  const fs = require('fs');
  try {
    const c = JSON.parse(fs.readFileSync('$CONFIG_FILE', 'utf8'));
    console.log('GuideMode Status');
    console.log('================');
    console.log('Server:   ' + (c.serverUrl || 'not set'));
    console.log('Team:     ' + (c.tenantName || 'not set'));
    console.log('User:     ' + (c.username || c.name || 'not set'));
    console.log('API Key:  ' + (c.apiKey ? c.apiKey.substring(0, 10) + '...' : 'not set'));
    console.log('');
    console.log('Sessions will sync automatically on session end.');
  } catch (e) {
    console.error('Error reading config: ' + e.message);
    process.exit(1);
  }
" 2>/dev/null
