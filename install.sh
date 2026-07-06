#!/bin/bash
# Self-contained installer for the myccstatusline look (curr+crdts / fable+wkly lines).
# Usage:  bash install.sh
# Needs:  bun (bunx), python3, curl, and a logged-in Claude Code (~/.claude/.credentials.json).
set -e
CFG="$HOME/.config/ccstatusline"
mkdir -p "$CFG" "$HOME/.cache/ccstatusline"

# 1. status line layout  (unquoted heredoc so $HOME expands into the widget paths)
cat > "$CFG/settings.json" <<CCSL_SETTINGS
{
  "version": 3,
  "lines": [
    [
      { "id": "l1-model", "type": "model", "color": "white", "rawValue": true },
      { "id": "l1-sep1", "type": "separator", "color": "gray", "character": " | " },
      { "id": "l1-ctx", "type": "context-percentage", "color": "white", "rawValue": false },
      { "id": "l1-sep2", "type": "separator", "color": "gray", "character": " | " },
      { "id": "l1-cwd", "type": "current-working-dir", "color": "white", "rawValue": true,
        "metadata": { "segments": "1", "abbreviateHome": "true" } },
      { "id": "l1-branch", "type": "git-branch", "color": "gray" }
    ],
    [
      { "id": "l2-label", "type": "custom-text", "color": "white", "customText": "curr" },
      { "id": "l2-bar", "type": "session-usage", "color": "green", "rawValue": true,
        "metadata": { "display": "progress-short" } },
      { "id": "l2-reset-icon", "type": "custom-text", "color": "green", "customText": "⟳" },
      { "id": "l2-reset", "type": "reset-timer", "color": "green", "rawValue": true,
        "metadata": { "display": "time" } },
      { "id": "l2-sep", "type": "separator", "color": "gray", "character": " | " },
      { "id": "l2-credits-label", "type": "custom-text", "color": "white", "customText": "crdts " },
      { "id": "l2-credits", "type": "custom-command", "color": "green", "rawValue": true,
        "commandPath": "$HOME/.config/ccstatusline/credits.sh", "timeout": 900 }
    ],
    [
      { "id": "l3-label", "type": "custom-text", "color": "white", "customText": "fable  " },
      { "id": "l3-bar", "type": "custom-command", "color": "green", "rawValue": true,
        "commandPath": "$HOME/.config/ccstatusline/fable-weekly.sh", "timeout": 900 },
      { "id": "l3-sep1", "type": "separator", "color": "gray", "character": " | " },
      { "id": "l3-label2", "type": "custom-text", "color": "white", "customText": "wkly " },
      { "id": "l3-bar2", "type": "weekly-usage", "color": "green", "rawValue": true,
        "metadata": { "display": "progress-short" } },
      { "id": "l3-reset-icon", "type": "custom-text", "color": "green", "customText": "⟳" },
      { "id": "l3-reset", "type": "weekly-reset-timer", "color": "green", "rawValue": true,
        "metadata": { "display": "time" } }
    ]
  ],
  "flexMode": "full-minus-40",
  "compactThreshold": 60,
  "colorLevel": 2,
  "defaultPadding": " ",
  "inheritSeparatorColors": false,
  "globalBold": false,
  "minimalistMode": false,
  "powerline": {
    "enabled": false,
    "separators": [""],
    "separatorInvertBackground": [false],
    "startCaps": [],
    "endCaps": [],
    "theme": "catppuccin",
    "autoAlign": true,
    "continueThemeAcrossLines": false
  }
}
CCSL_SETTINGS

# 2. fable weekly widget
cat > "$CFG/fable-weekly.sh" <<'CCSL_FABLE'
#!/bin/bash
# Fable weekly usage for ccstatusline custom-command widget.
# ponytail: prints from cache instantly (widget timeout is 1s); refreshes in background every 60s
CACHE="$HOME/.cache/ccstatusline/fable-weekly"

refresh() {
    local token
    token=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.claude/.credentials.json')))['claudeAiOauth']['accessToken'])" 2>/dev/null) || return
    curl -s --max-time 8 https://api.anthropic.com/api/oauth/usage \
        -H "Authorization: Bearer $token" -H "anthropic-beta: oauth-2025-04-20" |
    python3 -c '
import json, sys
d = json.load(sys.stdin)
lims = [l for l in d.get("limits", []) if l.get("kind") == "weekly_scoped"
        and ((l.get("scope") or {}).get("model") or {}).get("display_name") == "Fable"]
if not lims:
    sys.exit(1)
pct = max(0, min(100, lims[0]["percent"]))
filled = round(pct / 100 * 16)
print(f"[{chr(9608)*filled}{chr(9617)*(16-filled)}] {pct:.1f}%")
' > "$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"
}

mkdir -p "$(dirname "$CACHE")"
age=$(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) ))
if [ "$age" -gt 60 ]; then
    touch "$CACHE"  # stampede guard: statusline re-runs every few hundred ms
    refresh >/dev/null 2>&1 &
fi
cat "$CACHE" 2>/dev/null
CCSL_FABLE

# 3. usage-credits widget
cat > "$CFG/credits.sh" <<'CCSL_CREDITS'
#!/bin/bash
# Usage-credits (extra_usage) % for ccstatusline custom-command widget.
# ponytail: prints from cache instantly (widget timeout is 1s); refreshes in background every 60s
CACHE="$HOME/.cache/ccstatusline/credits"

refresh() {
    local token
    token=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.claude/.credentials.json')))['claudeAiOauth']['accessToken'])" 2>/dev/null) || return
    curl -s --max-time 8 https://api.anthropic.com/api/oauth/usage \
        -H "Authorization: Bearer $token" -H "anthropic-beta: oauth-2025-04-20" -H "User-Agent: claude-code/1.0" |
    python3 -c '
import json, sys
eu = (json.load(sys.stdin).get("extra_usage") or {})
if not eu.get("is_enabled"):
    sys.exit(1)  # credits off -> print nothing
pct = max(0, min(100, eu.get("utilization", 0)))
filled = round(pct / 100 * 16)
print(f"[{chr(9608)*filled}{chr(9617)*(16-filled)}] {pct:.0f}%")
' > "$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"
}

mkdir -p "$(dirname "$CACHE")"
age=$(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) ))
if [ "$age" -gt 60 ]; then
    touch "$CACHE"  # stampede guard: statusline re-runs every few hundred ms
    refresh >/dev/null 2>&1 &
fi
cat "$CACHE" 2>/dev/null
CCSL_CREDITS
chmod +x "$CFG/fable-weekly.sh" "$CFG/credits.sh"

# 4. wire ccstatusline into Claude Code (merge, don't clobber other settings)
python3 - <<'CCSL_WIRE'
import json, os
p = os.path.expanduser("~/.claude/settings.json")
try:
    d = json.load(open(p))
except FileNotFoundError:
    d = {}
d["statusLine"] = {"type": "command", "command": "bunx -y ccstatusline@latest", "padding": 0}
os.makedirs(os.path.dirname(p), exist_ok=True)
json.dump(d, open(p, "w"), indent=2)
print("wired statusLine ->", p)
CCSL_WIRE

echo "Done. Start a new Claude Code session to see the status line."
