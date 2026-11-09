#!/usr/bin/env bash
# Claude Code status line.
#
#   Opus 5.5 | ███▒▒▒ 42% ⧗ 12 min | 73%↑ 1:48 | libs/Dress-Code | 🌿 rule-fixes | 📁 scratch
#
# Segments (each hidden when it has nothing to say):
#   model        - who's answering right now
#   context      - bar + %, green <50, yellow <80, red after
#   cache timer  - minutes until the prompt cache expires; hidden when little is at stake
#   plan usage   - the rate-limit window closest to its limit; ↑ = burning faster than the clock
#   limit reset  - h:mm until that window starts over
#   project      - last two path parts, clickable (opens the folder)
#   worktree     - shown only inside a git worktree
#   scratchpad   - shown only when Claude's scratchpad has files, clickable
#
# Input: the JSON Claude Code pipes on stdin. Requires jq.

input=$(cat)
command -v jq >/dev/null 2>&1 || { printf 'statusline: install jq'; exit 0; }

# Pull every field in one jq pass. \x1f (unit separator) is not IFS whitespace,
# so empty fields keep their position (tabs would collapse).
IFS=$'\x1f' read -r model ctx_pct cache_warm cache_expires cache_stake \
  rl5_pct rl5_reset rl7_pct rl7_reset proj_dir cur_dir worktree session_id < <(
  jq -r '[
    (.model.display_name // ""),
    (.context_window.used_percentage // ""),
    (.prompt_cache.warm // false),
    (.prompt_cache.expires_at // ""),
    (.prompt_cache.recache_tokens_if_cold // .prompt_cache.cache_write_tokens // 0),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // ""),
    (.rate_limits.seven_day.resets_at // ""),
    (.workspace.project_dir // .cwd // ""),
    (.workspace.current_dir // .cwd // ""),
    (.worktree.name // .workspace.git_worktree // ""),
    (.session_id // "")
  ] | map(tostring) | join("\u001f")' <<<"$input"
)

now=$(date +%s)
ESC=$'\e'
RST="${ESC}[0m"; DIM="${ESC}[2m"
GREEN="${ESC}[32m"; YELLOW="${ESC}[33m"; RED="${ESC}[31m"; LEAF="${ESC}[92m"
SEP=" ${DIM}|${RST} "

# Cache countdown only matters when a cold cache would cost a real rebuild.
CACHE_MIN_TOKENS=${STATUSLINE_CACHE_MIN_TOKENS:-20000}

color_for() { # $1 = integer percent
  if   (( $1 < 50 )); then printf '%s' "$GREEN"
  elif (( $1 < 80 )); then printf '%s' "$YELLOW"
  else printf '%s' "$RED"; fi
}

# OSC 8 hyperlink: terminals that support it make the text clickable.
link() { printf '%s]8;;file://%s%s\\%s%s]8;;%s\\' "$ESC" "$1" "$ESC" "$2" "$ESC" "$ESC"; }

parts=()

# --- model ---------------------------------------------------------------
[[ -n $model ]] && parts+=("$model")

# --- context window + cache countdown ------------------------------------
seg=""
if [[ -n $ctx_pct ]]; then
  pct=$(printf '%.0f' "$ctx_pct")
  width=10
  filled=$(( (pct * width + 50) / 100 )); (( filled > width )) && filled=$width
  c=$(color_for "$pct")
  bar="${c}"; for ((i=0; i<filled; i++)); do bar+="█"; done
  bar+="${RST}${DIM}"; for ((i=filled; i<width; i++)); do bar+="▒"; done
  seg="${bar}${RST} ${c}${pct}%${RST}"
fi
if [[ $cache_warm == true && -n $cache_expires && ${cache_stake%.*} -ge $CACHE_MIN_TOKENS ]]; then
  left=$(( (cache_expires - now + 59) / 60 ))
  (( left > 0 )) && seg+="${seg:+ }${YELLOW}⧗ ${left} min${RST}"
fi
[[ -n $seg ]] && parts+=("$seg")

# --- plan usage: the window closest to its limit -------------------------
pick_pct=""; pick_reset=""; pick_len=0
if [[ -n $rl5_pct ]]; then pick_pct=$rl5_pct; pick_reset=$rl5_reset; pick_len=18000; fi
if [[ -n $rl7_pct ]] && { [[ -z $pick_pct ]] || (( ${rl7_pct%.*} > ${pick_pct%.*} )); }; then
  pick_pct=$rl7_pct; pick_reset=$rl7_reset; pick_len=604800
fi
if [[ -n $pick_pct ]]; then
  pct=$(printf '%.0f' "$pick_pct")
  seg="$(color_for "$pct")${pct}%"
  if [[ -n $pick_reset ]]; then
    remain=$(( pick_reset - now )); (( remain < 0 )) && remain=0
    # Ahead of the clock: used share of the limit > elapsed share of the window.
    elapsed_pct=$(( (pick_len - remain) * 100 / pick_len ))
    (( pct > elapsed_pct )) && seg+="↑"
    seg+="${RST} $(( remain / 3600 )):$(printf '%02d' $(( remain % 3600 / 60 )))"
  else
    seg+="${RST}"
  fi
  parts+=("$seg")
fi

# --- project ------------------------------------------------------------
if [[ -n $proj_dir ]]; then
  name=$(basename "$(dirname "$proj_dir")")/$(basename "$proj_dir")
  [[ $(dirname "$proj_dir") == / ]] && name=$(basename "$proj_dir")
  parts+=("$(link "$proj_dir" "$name")")
fi

# --- git worktree --------------------------------------------------------
[[ -n $worktree ]] && parts+=("${LEAF}🌿${RST} $worktree")

# --- scratchpad (only when it holds files) -------------------------------
if [[ -n $session_id ]]; then
  for d in "${TMPDIR:-/tmp}"/claude-"$(id -u)"/*/"$session_id"/scratchpad \
           /tmp/claude-"$(id -u)"/*/"$session_id"/scratchpad; do
    if [[ -d $d && -n $(ls -A "$d" 2>/dev/null) ]]; then
      parts+=("📁 $(link "$d" scratch)"); break
    fi
  done
fi

out=""
for p in "${parts[@]}"; do out+="${out:+$SEP}$p"; done
printf '%s' "$out"
