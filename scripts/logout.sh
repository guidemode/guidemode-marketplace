#!/usr/bin/env bash
# GuideMode logout - removes stored credentials

CONFIG_FILE="$HOME/.guidemode/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Not logged in (no config file found)."
  exit 0
fi

rm -f "$CONFIG_FILE"
echo "Logged out. Config file removed."
echo "Sessions will no longer sync to GuideMode."
