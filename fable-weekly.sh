#!/bin/bash
# Fable weekly usage for ccstatusline custom-command widget.
# ponytail: prints from cache instantly (widget timeout is 1s); refreshes in background every 60s
# follows the active Claude account: uses $CLAUDE_CONFIG_DIR (set per account) and falls back to ~/.claude
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CACHE="$HOME/.cache/ccstatusline/fable-weekly-$(basename "$CFG")"

# token: Linux reads the credentials file; macOS reads the login keychain (one-time "Always Allow").
get_token() {
    local f="$CFG/.credentials.json" j
    if [ -f "$f" ]; then j=$(cat "$f")
    else j=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || return 1; fi
    printf '%s' "$j" | python3 -c "import json,sys;print(json.load(sys.stdin)['claudeAiOauth']['accessToken'])" 2>/dev/null
}

refresh() {
    local token
    token=$(get_token) || return
    curl -s --max-time 8 https://api.anthropic.com/api/oauth/usage \
        -H "Authorization: Bearer $token" -H "anthropic-beta: oauth-2025-04-20" -H "User-Agent: claude-code/1.0" |
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
mtime=$(stat -c %Y "$CACHE" 2>/dev/null || stat -f %m "$CACHE" 2>/dev/null || echo 0)  # GNU || BSD stat
age=$(( $(date +%s) - mtime ))
if [ "$age" -gt 60 ]; then
    touch "$CACHE"  # stampede guard: statusline re-runs every few hundred ms
    refresh >/dev/null 2>&1 &
fi
cat "$CACHE" 2>/dev/null
