# myccstatusline

My [ccstatusline](https://www.npmjs.com/package/ccstatusline) setup for Claude Code — a 3-line status bar with two extras the library doesn't ship:

```
opus 4.8 | 42% | ~/projects/myccstatusline main
curr  [█████░░░░░░░░░░░] 10% ⟳ 4h32m | crdts [█████████░░░░░░░] 56%
fable [██░░░░░░░░░░░░░░] 14% ⟳ 5d18h | wkly [██████░░░░░░░░░░] 40%
```

- **curr** — 5-hour session usage + reset timer (built-in `session-usage`)
- **crdts** — usage credits % (`extra_usage.utilization` from the OAuth usage API) — *no built-in widget, custom script*
- **fable** — Fable weekly usage % (`weekly_scoped` limit) — *no built-in widget, custom script*
- **wkly** — combined weekly usage + reset timer (built-in `weekly-usage`)

The two custom widgets query `https://api.anthropic.com/api/oauth/usage` directly (token from `~/.claude/.credentials.json`) and cache to `~/.cache/ccstatusline` with a 60s background refresh, because the custom-command widget has a ~1s render timeout.

## Install

Needs `bun`, `python3`, `curl`, and a logged-in Claude Code. Then either:

```bash
git clone https://github.com/thariman/myccstatusline && bash myccstatusline/install.sh
```

or grab just the self-contained installer:

```bash
curl -fsSL https://raw.githubusercontent.com/thariman/myccstatusline/main/install.sh | bash
```

Start a new Claude Code session to see it. `install.sh` writes the layout + widget scripts to `~/.config/ccstatusline/` and points Claude Code's `statusLine` at `bunx ccstatusline`.

## Platforms

Tested on **Linux** and **macOS**. The custom widgets read the OAuth token cross-platform: from `~/.claude/.credentials.json` on Linux, and from the login **Keychain** (`Claude Code-credentials`) on macOS — the first read triggers a one-time prompt, click **Always Allow**. On macOS the widgets only work in the desktop Claude Code session (the login keychain is locked over SSH).

## Files

| File | What |
|------|------|
| `install.sh` | Self-contained installer (embeds everything). **Generated — don't hand-edit.** |
| `settings.json` | The ccstatusline layout (source of truth). |
| `fable-weekly.sh` | Fable weekly-usage widget. |
| `credits.sh` | Usage-credits widget. |
| `build.sh` | Regenerates `install.sh` from the three files above. |

## Customize

Edit `settings.json` / the `*.sh` widgets, then rebuild the installer:

```bash
bash build.sh
```

Note: usage **credits** are a *monthly* pool — the `⟳` timer on line 2 is the 5-hour session reset, not the credits reset.
