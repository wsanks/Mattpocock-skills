#!/bin/bash
# Locate and open the architecture-review HTML report outside the repo.
# Usage:
#   report.sh path         -> prints a fresh <tmpdir>/architecture-review-<timestamp>.html path
#   report.sh open <file>  -> opens <file> in the default browser and prints its absolute path
set -euo pipefail

case "${1:-}" in
  path)
    # $TMPDIR is set on macOS and most Linux setups; fall back to /tmp otherwise.
    dir="${TMPDIR:-/tmp}"
    echo "${dir%/}/architecture-review-$(date +%Y%m%d-%H%M%S).html"
    ;;
  open)
    file="${2:?Usage: $0 open <file>}"
    [ -f "$file" ] || { echo "No report at $file; write it first." >&2; exit 1; }
    abs="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
    if grep -qi microsoft /proc/version 2>/dev/null && command -v wslview >/dev/null; then
      wslview "$abs" >/dev/null 2>&1 &
    elif command -v open >/dev/null && [ "$(uname)" = "Darwin" ]; then
      open "$abs"
    elif command -v xdg-open >/dev/null; then
      xdg-open "$abs" >/dev/null 2>&1 &
    elif command -v cmd.exe >/dev/null; then
      cmd.exe /c start "" "$abs"
    else
      echo "No browser opener found; open the file manually." >&2
    fi
    echo "$abs"
    ;;
  *)
    echo "Usage: $0 path | open <file>" >&2
    exit 1
    ;;
esac
