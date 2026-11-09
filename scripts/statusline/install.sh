#!/usr/bin/env bash
# Install the status line for every Claude Code session on this machine.
#
# Symlinks statusline.sh into ~/.claude and sets `statusLine` in
# ~/.claude/settings.json (other settings are kept). Because it's a symlink,
# `git pull` in this repo updates the installed status line. Safe to re-run.
set -euo pipefail

command -v jq >/dev/null || { echo "jq is required (macOS: brew install jq)" >&2; exit 1; }

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/statusline.sh"
dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$dir/settings.json"

mkdir -p "$dir"
chmod +x "$src"
ln -sfn "$src" "$dir/statusline.sh"

[[ -s $settings ]] || echo '{}' >"$settings"
cp "$settings" "$settings.bak"
tmp=$(mktemp)
# refreshInterval re-runs the script every 60s so the countdowns tick.
jq --arg cmd "$dir/statusline.sh" \
  '.statusLine = {type: "command", command: $cmd, padding: 0, refreshInterval: 60}' \
  "$settings" >"$tmp" && mv "$tmp" "$settings"

echo "Status line installed → $dir/statusline.sh (backup: $settings.bak)"
echo "Restart Claude Code to see it."
