#!/bin/bash
# Regenerate the self-contained install.sh from the source files in this repo.
# Run this after editing settings.json / *.sh so install.sh stays in sync.
set -e
cd "$(dirname "$0")"
python3 - <<'GEN'
import os
settings = open("settings.json").read().rstrip("\n")   # already uses $HOME
fable    = open("fable-weekly.sh").read().rstrip("\n")
credits  = open("credits.sh").read().rstrip("\n")

out = f'''#!/bin/bash
# Self-contained installer for the myccstatusline look (curr+crdts / fable+wkly lines).
# Usage:  bash install.sh
# Needs:  bun (bunx), python3, curl, and a logged-in Claude Code (~/.claude/.credentials.json).
set -e
CFG="$HOME/.config/ccstatusline"
mkdir -p "$CFG" "$HOME/.cache/ccstatusline"

# 1. status line layout  (unquoted heredoc so $HOME expands into the widget paths)
cat > "$CFG/settings.json" <<CCSL_SETTINGS
{settings}
CCSL_SETTINGS

# 2. fable weekly widget
cat > "$CFG/fable-weekly.sh" <<'CCSL_FABLE'
{fable}
CCSL_FABLE

# 3. usage-credits widget
cat > "$CFG/credits.sh" <<'CCSL_CREDITS'
{credits}
CCSL_CREDITS
chmod +x "$CFG/fable-weekly.sh" "$CFG/credits.sh"

# 4. wire ccstatusline into Claude Code (merge, don't clobber other settings)
python3 - <<'CCSL_WIRE'
import json, os
p = os.path.expanduser("~/.claude/settings.json")
try:
    d = json.load(open(p))
except FileNotFoundError:
    d = {{}}
d["statusLine"] = {{"type": "command", "command": "bunx -y ccstatusline@latest", "padding": 0}}
os.makedirs(os.path.dirname(p), exist_ok=True)
json.dump(d, open(p, "w"), indent=2)
print("wired statusLine ->", p)
CCSL_WIRE

echo "Done. Start a new Claude Code session to see the status line."
'''
open("install.sh", "w").write(out)
os.chmod("install.sh", 0o755)
print("regenerated install.sh:", len(out), "bytes")
GEN
