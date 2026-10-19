#!/bin/bash
# Merge the block-dangerous-git PreToolUse hook into a Claude Code settings file.
# Usage: merge-hook-settings.sh <settings.json> <hook-command>
# Creates the file if missing, keeps every existing setting and hook, and is
# safe to re-run: a hook whose command is already registered is left alone.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <settings.json> <hook-command>" >&2
  exit 1
fi

SETTINGS="$1"
HOOK_CMD="$2"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not installed. Install it (e.g. 'brew install jq' or 'apt-get install jq') and re-run." >&2
  exit 1
fi

mkdir -p "$(dirname "$SETTINGS")"
[ -s "$SETTINGS" ] || echo '{}' > "$SETTINGS"

if ! jq empty "$SETTINGS" 2>/dev/null; then
  echo "$SETTINGS is not valid JSON. Fix it by hand first; nothing was changed." >&2
  exit 1
fi

if jq -e --arg cmd "$HOOK_CMD" \
  '[.hooks.PreToolUse[]?.hooks[]?.command] | index($cmd) != null' \
  "$SETTINGS" >/dev/null; then
  echo "Hook already registered in $SETTINGS; nothing changed."
  exit 0
fi

# Write to a temp file and move it into place so a failed jq run never truncates the settings.
TMP="$(mktemp)"
jq --arg cmd "$HOOK_CMD" \
  '.hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{"matcher": "Bash", "hooks": [{"type": "command", "command": $cmd}]}])' \
  "$SETTINGS" > "$TMP"
mv "$TMP" "$SETTINGS"

echo "Added PreToolUse hook to $SETTINGS:"
jq '.hooks.PreToolUse' "$SETTINGS"
