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
