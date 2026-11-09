# Claude Code status line

```
Opus 5.5 | ████▒▒▒▒▒▒ 42% ⧗ 12 min | 73%↑ 1:48 | libs/Dress-Code | 🌿 rule-fixes | 📁 scratch
```

| Segment | Shows |
|---|---|
| Model | Who's answering right now. |
| Context window | Bar + %. Green under 50%, yellow under 80%, then red. |
| ⧗ Cache countdown | Minutes until the prompt cache expires. Hidden when a rebuild would cost under 20k tokens (`STATUSLINE_CACHE_MIN_TOKENS`). |
| Plan usage | The rate-limit window (5-hour or 7-day) closest to its limit. `↑` = usage is running ahead of the clock. |
| Limit reset | `h:mm` until that window starts over. |
| Project | Last two parts of the project path. Click to open the folder. |
| 🌿 Worktree | Only inside a git worktree. |
| 📁 Scratchpad | Only when Claude's scratchpad has files. Clickable. |

Clickable segments use OSC 8 links (iTerm2, Ghostty, WezTerm, VS Code, recent Terminal.app). Segments with no data hide themselves; rate limits appear only on a Claude subscription plan.

## Install (once per machine)

```bash
scripts/statusline/install.sh
```

Needs `jq` (`brew install jq` if missing). The installer symlinks the script into `~/.claude/` and sets `statusLine` in `~/.claude/settings.json`, keeping your other settings and writing a `.bak`. Restart Claude Code afterwards. `git pull` updates the installed copy.
