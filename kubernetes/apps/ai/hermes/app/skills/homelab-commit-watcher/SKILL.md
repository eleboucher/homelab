---
name: homelab-commit-watcher
description: Watch homelab/gitops peer repositories on the k8s-at-home GitHub topic for interesting commits, rank them, and post a summary to a Discord channel via webhook.
version: 3.4.0
author: erwanleboucher
license: MIT
required_environment_variables:
    - name: HOMELAB_GH_TOKEN
      prompt: "GitHub token with public_repo scope"
      help: "Create at https://github.com/settings/tokens — only public_repo is required. Named HOMELAB_GH_TOKEN (not GH_TOKEN) because Hermes blocks provider credentials with the standard name; see GHSA-rhgp-j443-p4."
      required_for: "Fetching commits from public k8s-at-home repos via the GraphQL API."
    - name: DISCORD_WEBHOOK
      prompt: "Discord webhook URL for the homelab channel"
      help: "Channel Settings → Integrations → Webhooks → New Webhook → Copy URL."
      required_for: "Posting the rendered digest to Discord."
metadata:
    hermes:
        tags: [homelab, gitops, github, kubernetes, discord, digest]
        category: devops
---

# Homelab Commit Watcher

Fetch commits from `k8s-at-home`-tagged repos over the last 24h, drop bot/noise, rank what's left, and post a digest to Discord.

## When to Use

Run when the user asks any of:

- "find interesting commits on my homelab peers"
- "homelab commit watcher"
- "check homelab repos for updates"
- "what's new in homelab repos"
- "post homelab commit summary"

Also runs daily on the Hermes cron job `homelab-peers-commit-watcher`.

## Quick Reference

| Thing          | Value                                                                                            |
| -------------- | ------------------------------------------------------------------------------------------------ |
| Script         | `fetch_k8s_repos.py` in this directory; runtime copy at `/opt/data/workspace/fetch_k8s_repos.py` |
| Feed output    | `/tmp/commit-watcher/feed-YYYY-MM-DD.md` (mirror at `~/commit-watcher-YYYY-MM-DD.md`)            |
| Final digest   | **10 commits max, ≤ 2 per repo**                                                                 |
| Lookback       | 24h (`LOOKBACK_HOURS` in script)                                                                 |
| Discord limits | 2000 chars per `content`; webhook accepts `flags` field                                          |

## Procedure

> **Two things matter most. Everything else is mechanical.**
>
> 1. **Pick commits that are genuinely interesting to a homelab operator.** A short, signal-dense digest beats a padded one. See step 3.
> 2. **Match the output format byte-for-byte.** One bullet per line, exact separators, exact whitespace, `flags: 4100` on every POST, no `(cont.)` headers on chunks. See steps 4–5.

### 1. Run the fetcher

```bash
HOMELAB_GH_TOKEN=<token> python3 fetch_k8s_repos.py
```

The script handles bot-author detection, merge-commit filtering, and renovate-style version-bump removal. Do not redo any of that — see `BOT_LOGINS`, `BOT_BRANCH_RE`, `BOT_CONTENT_RE` in the script for the canonical rules.

Output lands at `/tmp/commit-watcher/feed-YYYY-MM-DD.md`.

### 2. Load the feed

Plain markdown — no JSON parsing. Shape:

```
since: <iso-timestamp>
generated: <iso-timestamp>

## <owner>/<repo>
- <author>: <commit message> · <commit url>
- <author>: <commit message> · <commit url>

## <owner>/<repo>
- <author>: <commit message> · <commit url>
```

Repos are pre-sorted newest-commit-first; commits within each repo are newest-first.

### 3. Pick the top entries

Pick at most **10 commits**, **max 2 per repo**. Optimize for signal — a 5-commit digest beats a padded 10-commit one.

**Pick**: architectural change, real infra work (storage / networking / GitOps / cluster ops), a message that explains *why*, a notable bug fix with a clear cause, a new tool or pattern others might copy, intentional cleanup with a stated reason.

**Skip**: typo fixes, "sync"/"lint"/README touch-ups, lock-file noise, bare `fix:` with no body, patch bumps with no explanation, near-duplicates (bundle them via the grouping rule).

Tie-break by feed order (newest first).

### 4. Render output

Discord-compatible markdown.

**Template:**

```markdown
# Homelab commits — YYYY-MM-DD

<emoji> <owner>/<repo>

- <message> — <author> - <commit-url>
- <message> — <author> - <commit-url>
```

**Rules:**

- **Header date**: first 10 chars of the feed's `generated:` line.
- **Emoji per repo**: cycle `🛠️ 🔧 📦 🚀 🌐 ⚙️` in feed order, reset each run.
- **Separators**: `—` (em-dash) between message and author, `-` (hyphen) between author and URL.
- **Author**: copy verbatim from the feed (text before `:`). No enrichment, no invented full names.
- **One bullet = one line.** Never split a bullet across lines, never indent the URL — Discord renders the next commit as a nested bullet if you do.
- **Whitespace**: one blank line between repo header and first bullet; no blank lines between bullets in the same repo; one blank line between repo sections; no leading spaces on bullet lines.
- **Grouping**: merge adjacent commits with shared scope (same parenthetical or same first 3 words) into one bullet; concatenate their URLs on the same line.
- **Empty feed**: post `# Homelab commits — YYYY-MM-DD\n\n_No notable commits in the last 24h._`

### 5. Post to Discord

POST the rendered markdown to `$DISCORD_WEBHOOK` — nothing else. No prelude, no commentary.

**Required JSON shape on every POST:**

```python
import os, httpx
httpx.post(
    os.environ["DISCORD_WEBHOOK"],
    json={"content": payload, "flags": 4100},
    timeout=30,
).raise_for_status()
```

`flags: 4100` = `SUPPRESS_EMBEDS` (4) | `SUPPRESS_NOTIFICATIONS` (4096). Without it Discord renders an embed card for every URL and pings the channel.

**On overflow** (Discord caps `content` at 2000 chars): split at repo-block boundaries and POST each chunk in feed order with `flags: 4100`. Chunks after the first **start directly with their first `<emoji> <owner>/<repo>` line** — no `(cont.)` header, no banner.

If `DISCORD_WEBHOOK` is unset, surface the rendered markdown for manual posting and stop.

## Pitfalls

- **`HOMELAB_GH_TOKEN` missing/expired**: script exits with `HOMELAB_GH_TOKEN env var required`, or 401 on first request. Re-issue the token. Do not rename back to `GH_TOKEN` — Hermes scrubs it (GHSA-rhgp-j443-p4).
- **Script crash mid-batch**: connection retries (2×) and status-code retries (5×) are wired in. If both exhaust, `RuntimeError: Exhausted retries` — re-run later, partial output is not written.
- **GitHub returns 200 with rate-limit error**: handled by `_is_rate_limit_error`. No action.
- **Deployment path drift**: source-of-truth is this directory in-repo. Init container copies the script to `/opt/data/workspace/`, SKILL.md to `/opt/data/skills/homelab/`. Edit the repo copy; Flux + reloader redeploy.
- **`DISCORD_WEBHOOK` unset or revoked**: POST returns 401/404. Re-create webhook (channel → Integrations → Webhooks).
- **Discord webhook rate limits**: 5 requests / 2 seconds. On many chunks, watch for HTTP 429 + `Retry-After`.
- **Author handle is a login, not a real name** (e.g. `joryirving` not "Jory Irving") — intentional.

## Verification

- `feed-YYYY-MM-DD.md` exists in `/tmp/commit-watcher/` and starts with `since:` / `generated:` lines.
- `grep -c '^- Renovate Bot:' feed-YYYY-MM-DD.md` returns `0`.
- `grep -ci 'Merge pull request' feed-YYYY-MM-DD.md` returns `0`.
- Final digest: ≤ 10 commit bullets, ≤ 2 per repo.
- Each Discord POST returns HTTP 204.

## How to Adjust

- **Bot/merge/version-bump filtering, lookback**: edit `fetch_k8s_repos.py` constants.
- **Selection rubric, per-repo cap, "interesting" definition**: edit Procedure → step 3.
- **Output format / emoji / separators**: edit Procedure → step 4.
- **Discord target**: rotate `DISCORD_WEBHOOK`. Never hardcode in the skill.
