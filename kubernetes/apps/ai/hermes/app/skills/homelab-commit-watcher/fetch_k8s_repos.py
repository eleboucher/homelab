#!/usr/bin/env python3
"""Daily feed of commits across the k8s-at-home GitHub topic. Rolling 7d window,
bots filtered, commits in the last 24h tagged `[24h]` for the consuming SKILL."""

import os
import re
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx

GITHUB_API = "https://api.github.com/graphql"
TOPIC = "k8s-at-home"
OUTPUT_DIR = Path("/tmp/commit-watcher")
BATCH_SIZE = 15
LOOKBACK_HOURS = 168  # 7d
RECENT_HOURS = 24

BOT_LOGINS = {
    "dependabot",
    "dependabot-preview",
    "renovate",
    "renovate-bot",
    "github-actions",
    "pre-commit-ci",
    "imgbot",
    "allcontributors",
    "release-please",
    "snyk-bot",
    "mend-bot",
    "step-security-bot",
}


def gh_token() -> str:
    # HOMELAB_GH_TOKEN is the primary name — Hermes blocks GH_TOKEN/GITHUB_TOKEN
    # via its provider credential scrubbing (see GHSA-rhgp-j443-p4).
    token = (
        os.environ.get("HOMELAB_GH_TOKEN")
        or os.environ.get("GH_TOKEN")
        or os.environ.get("GITHUB_TOKEN")
    )
    if not token:
        sys.exit("HOMELAB_GH_TOKEN env var required")
    return token


def _backoff_seconds(response: httpx.Response, attempt: int) -> int:
    retry_after = response.headers.get("retry-after")
    if retry_after:
        try:
            return max(1, int(retry_after))
        except ValueError:
            pass
    reset = response.headers.get("x-ratelimit-reset")
    if reset:
        try:
            return max(1, int(reset) - int(time.time()) + 1)
        except ValueError:
            pass
    return 2**attempt


def _is_rate_limit_error(errors: list[dict]) -> bool:
    for e in errors:
        msg = (e.get("message") or "").lower()
        if "rate limit" in msg or "abuse" in msg:
            return True
    return False


def gql(client: httpx.Client, query: str, variables: dict) -> dict:
    for attempt in range(5):
        r = client.post(GITHUB_API, json={"query": query, "variables": variables})
        if r.status_code == 200:
            data = r.json()
            errors = data.get("errors")
            if errors and _is_rate_limit_error(errors):
                wait = _backoff_seconds(r, attempt)
                print(f"  rate-limited (200): retry in {wait}s", file=sys.stderr)
                time.sleep(min(wait, 120))
                continue
            if errors:
                # Surface only type+message — the raw `errors` payload can
                # echo request headers/extensions and we never want a token
                # to land in a stack trace.
                safe = [(e.get("type"), e.get("message")) for e in errors]
                raise RuntimeError(f"GraphQL errors: {safe}")
            return data["data"]
        if r.status_code in (403, 429, 502, 503, 504):
            wait = _backoff_seconds(r, attempt)
            print(f"  retry in {wait}s (status {r.status_code})", file=sys.stderr)
            time.sleep(min(wait, 120))
            continue
        r.raise_for_status()
    raise RuntimeError("Exhausted retries")


SEARCH_QUERY = """
query($q: String!, $cursor: String) {
  search(query: $q, type: REPOSITORY, first: 100, after: $cursor) {
    pageInfo { hasNextPage endCursor }
    nodes {
      ... on Repository {
        nameWithOwner
        owner { login }
        name
        isArchived
      }
    }
  }
}
"""


def fetch_repos(client: httpx.Client, since: str) -> list[dict]:
    # `pushed:>=<date>` drops repos with no activity in the lookback window before
    # we spend rate-limit budget on their commit history.
    query = f"topic:{TOPIC} pushed:>={since[:10]}"
    repos: list[dict] = []
    cursor = None
    while True:
        data = gql(client, SEARCH_QUERY, {"q": query, "cursor": cursor})
        s = data["search"]
        for node in s["nodes"]:
            if node and not node["isArchived"]:
                repos.append(node)
        if not s["pageInfo"]["hasNextPage"]:
            break
        cursor = s["pageInfo"]["endCursor"]
    return repos


def build_commits_query(batch: list[dict]) -> str:
    parts = ["query($since: GitTimestamp!) {"]
    for i, repo in enumerate(batch):
        owner = repo["owner"]["login"].replace('"', '\\"')
        name = repo["name"].replace('"', '\\"')
        parts.append(
            f'  r{i}: repository(owner: "{owner}", name: "{name}") {{\n'
            f"    nameWithOwner url\n"
            f"    defaultBranchRef {{\n"
            f"      name\n"
            f"      target {{\n"
            f"        ... on Commit {{\n"
            f"          history(since: $since, first: 100) {{\n"
            f"            nodes {{\n"
            f"              oid messageHeadline messageBody committedDate url\n"
            f"              additions deletions changedFilesIfAvailable\n"
            f"              author {{ name email user {{ login }} }}\n"
            f"            }}\n"
            f"          }}\n"
            f"        }}\n"
            f"      }}\n"
            f"    }}\n"
            f"  }}"
        )
    parts.append("}")
    return "\n".join(parts)


def _strip_bot_suffix(value: str) -> str:
    for suffix in ("[bot]", " bot", "-bot"):
        if value.endswith(suffix):
            return value[: -len(suffix)].strip()
    return value


def is_bot(author: dict) -> bool:
    user = author.get("user") or {}
    login = (user.get("login") or "").lower()
    name = (author.get("name") or "").lower()
    email = (author.get("email") or "").lower()

    for value in (login, name):
        if not value:
            continue
        if "[bot]" in value:
            return True
        if _strip_bot_suffix(value) in BOT_LOGINS:
            return True

    if "[bot]@" in email or "bot@" in email:
        return True
    if email.endswith("@users.noreply.github.com"):
        local = email.split("@", 1)[0].split("+", 1)[-1]
        if _strip_bot_suffix(local) in BOT_LOGINS:
            return True

    return False


BOT_BRANCH_RE = re.compile(
    r"\b(?:renovate|dependabot|pre-commit-ci)/",
    re.IGNORECASE,
)

# Renovate's signature commit shape — leaks through when humans squash-merge
# renovate PRs. `update chart` is gated on a version-bump continuation since
# the bare phrase can mean "update chart values" in human commits. The arrow
# chars only count when adjacent to a version-like token, since humans use →
# in legitimate headlines (e.g. "refactor: old → new").
BOT_CONTENT_RE = re.compile(
    r"\bupdate (?:image|dependency)\b"
    r"|\bupdate chart \S+ (?:\(|to\s+v?\d|→|➔|➜)",
    re.IGNORECASE,
)


def is_skippable_commit(message: str) -> bool:
    msg = message.lstrip().lower()
    if msg.startswith("merge pull request"):
        return True
    if BOT_BRANCH_RE.search(message):
        return True
    if BOT_CONTENT_RE.search(message):
        return True
    return False


BODY_MAX_CHARS = 1200
DIFF_MAX_LINES = 150


def _trim_body(body: str) -> str:
    body = body.strip()
    if not body:
        return ""
    if len(body) <= BODY_MAX_CHARS:
        return body
    cut = body.rfind("\n", 0, BODY_MAX_CHARS)
    if cut < BODY_MAX_CHARS // 2:
        cut = BODY_MAX_CHARS
    return body[:cut].rstrip() + "\n…"


def fetch_commit_diff(client: httpx.Client, owner: str, repo: str, sha: str) -> str:
    """Fetch the unified diff for one commit, capped at DIFF_MAX_LINES. Returns "" on failure."""
    url = f"https://api.github.com/repos/{owner}/{repo}/commits/{sha}"
    try:
        r = client.get(
            url,
            headers={"Accept": "application/vnd.github.diff"},
            timeout=15.0,
        )
    except Exception:
        return ""
    if r.status_code != 200:
        return ""
    lines = r.text.splitlines()
    if len(lines) <= DIFF_MAX_LINES:
        return r.text
    return "\n".join(lines[:DIFF_MAX_LINES]) + "\n…"


SUMMARY_SYSTEM_PROMPT = (
    "You are summarizing a single git commit for a homelab digest. "
    "Read the commit headline and diff carefully and output ONE short "
    "sentence (≤120 chars) describing what the commit actually does to "
    "the repository. Rules:\n"
    "- Past tense, action-led, plain prose. Peer is the implicit subject.\n"
    "- Focus on the NET EFFECT after the diff is applied. If files are "
    "removed, say 'removed X'. If added, say 'added X'. If both, say "
    "'replaced X with Y' or 'switched from X to Y' when the items are "
    "related (e.g. swapping one ingress controller for another).\n"
    "- Name specific tools, components, namespaces, version numbers when "
    "visible in the diff or headline.\n"
    "- Never include URLs, file paths verbatim, code, markdown, or quotation "
    "marks copied from the diff.\n"
    "- Output ONLY the summary sentence. No preamble, no quotes, no list "
    "markers, no trailing explanation."
)

SUMMARY_TIMEOUT = 90.0


def summarize_commit(
    client: httpx.Client,
    summary_url: str,
    summary_model: str,
    headline: str,
    diff: str,
) -> str:
    """One-sentence commit summary via OpenAI-compatible chat/completions.
    `client` must NOT carry a GitHub Bearer token. Returns "" on failure."""
    if not summary_url or not summary_model or not diff:
        return ""
    payload = {
        "model": summary_model,
        "messages": [
            {"role": "system", "content": SUMMARY_SYSTEM_PROMPT},
            {"role": "user", "content": f"Headline: {headline}\n\nDiff:\n{diff}"},
        ],
        "max_tokens": 80,
        "temperature": 0.2,
        "stream": False,
    }
    try:
        r = client.post(
            f"{summary_url.rstrip('/')}/chat/completions",
            json=payload,
            timeout=SUMMARY_TIMEOUT,
        )
    except Exception as e:
        print(f"  summarizer: request failed: {e}", file=sys.stderr)
        return ""
    if r.status_code != 200:
        print(f"  summarizer: HTTP {r.status_code}", file=sys.stderr)
        return ""
    try:
        content = r.json()["choices"][0]["message"]["content"]
    except (KeyError, IndexError, ValueError, TypeError):
        return ""
    if not content:
        return ""
    raw_lines = content.splitlines()
    extra_nonempty = sum(1 for s in raw_lines[1:] if s.strip())
    if extra_nonempty:
        print(
            f"  summarizer: dropped {extra_nonempty} extra non-empty line(s)",
            file=sys.stderr,
        )
    line = next((s for s in raw_lines if s.strip()), "").strip()
    line = line.strip("`*_\"' ").replace("`", "").replace("“", "").replace("”", "")
    if len(line) > 200:
        print(f"  summarizer: truncating {len(line)} → 200 chars", file=sys.stderr)
        line = line[:197].rstrip() + "..."
    return line


SUMMARY_MIN_CHANGES = 5  # skip trivial commits to bound cron wall-time


def enrich_recent_with_summaries(
    client: httpx.Client,
    summary_url: str,
    summary_model: str,
    feed: list[dict],
) -> None:
    """Attach a `summary` field to substantive [24h] commits via REST→LLM.
    Diffs are fetched on the GitHub client; the LLM is called on a separate
    Bearer-only client so the GH token never reaches llama-cpp. No-op if
    SUMMARY_LLM_URL/SUMMARY_LLM_MODEL unset."""
    if not summary_url or not summary_model:
        print(
            "Summary LLM not configured (SUMMARY_LLM_URL/SUMMARY_LLM_MODEL) — "
            "skipping per-commit summarization",
            file=sys.stderr,
        )
        return
    candidates = [
        c
        for entry in feed
        for c in entry["c"]
        if c["recent"] and (c["add"] + c["del"]) >= SUMMARY_MIN_CHANGES
    ]
    if not candidates:
        return
    total = len(candidates)
    print(
        f"Summarizing {total} substantive [24h] commits via {summary_model}...",
        file=sys.stderr,
    )

    llm_headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "User-Agent": "k8s-at-home-feed/1.0 (summarizer)",
    }
    llm_api_key = (
        os.environ.get("SUMMARY_LLM_API_KEY")
        or os.environ.get("LLAMA_API_KEY")
        or ""
    ).strip()
    if llm_api_key:
        llm_headers["Authorization"] = f"Bearer {llm_api_key}"

    summarized = 0
    with httpx.Client(headers=llm_headers, timeout=SUMMARY_TIMEOUT) as llm_client:
        for i, c in enumerate(candidates, 1):
            if i % 50 == 0:
                print(f"  {i}/{total}", file=sys.stderr)
            parts = c["u"].rstrip("/").split("/")
            if len(parts) < 5 or parts[-2] != "commit":
                print(
                    f"  summarizer: bad commit URL, skipping: {c['u']}",
                    file=sys.stderr,
                )
                continue
            owner, repo_name, sha = parts[-4], parts[-3], parts[-1]
            diff = fetch_commit_diff(client, owner, repo_name, sha)
            if not diff:
                continue
            summary = summarize_commit(
                llm_client, summary_url, summary_model, c["m"], diff
            )
            if summary:
                c["summary"] = summary
                summarized += 1
    print(f"  done — {summarized}/{total} commits summarized", file=sys.stderr)


def render_feed(feed: list[dict], since: str, generated_at: str) -> str:
    lines = [f"since: {since}", f"generated: {generated_at}", ""]
    for entry in feed:
        lines.append(f"## {entry['r']}")
        for c in entry["c"]:
            stats = f"+{c['add']}/-{c['del']}, {c['files']}f"
            marker = "[24h] " if c["recent"] else ""
            date = c["d"][:10]
            lines.append(f"- {marker}{c['a']}: {c['m']} [{stats}] · {date} · {c['u']}")
            if c.get("summary"):
                lines.append(f"  summary: {c['summary']}")
            body = _trim_body(c.get("b", ""))
            if body:
                for line in body.splitlines():
                    lines.append(f"  > {line}")
        lines.append("")
    return "\n".join(lines)


def main() -> None:
    token = gh_token()
    now = datetime.now(timezone.utc)
    since = (now - timedelta(hours=LOOKBACK_HOURS)).isoformat()
    recent_cutoff = now - timedelta(hours=RECENT_HOURS)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "k8s-at-home-feed/1.0",
    }

    transport = httpx.HTTPTransport(retries=2)
    with httpx.Client(headers=headers, timeout=60.0, transport=transport) as client:
        print(f"Fetching repos in topic:{TOPIC} pushed since {since[:10]}...", file=sys.stderr)
        repos = fetch_repos(client, since)
        print(f"  {len(repos)} active repos", file=sys.stderr)

        feed: list[dict] = []
        total_commits = 0
        batches = (len(repos) + BATCH_SIZE - 1) // BATCH_SIZE
        for i in range(0, len(repos), BATCH_SIZE):
            batch = repos[i : i + BATCH_SIZE]
            print(f"  batch {i // BATCH_SIZE + 1}/{batches}", file=sys.stderr)
            data = gql(client, build_commits_query(batch), {"since": since})
            for j in range(len(batch)):
                node = data.get(f"r{j}")
                if not node or not node.get("defaultBranchRef"):
                    continue
                branch = node["defaultBranchRef"]
                target = branch.get("target") or {}
                history = target.get("history", {}).get("nodes", [])
                commits = []
                for c in history:
                    if is_bot(c["author"]) or is_skippable_commit(c["messageHeadline"]):
                        continue
                    user = c["author"].get("user") or {}
                    committed = datetime.fromisoformat(
                        c["committedDate"].replace("Z", "+00:00")
                    )
                    commits.append(
                        {
                            "m": c["messageHeadline"],
                            "b": c.get("messageBody") or "",
                            "d": c["committedDate"],
                            "recent": committed >= recent_cutoff,
                            "u": c["url"],
                            "a": user.get("login") or c["author"].get("name") or "unknown",
                            "add": c.get("additions") or 0,
                            "del": c.get("deletions") or 0,
                            "files": c.get("changedFilesIfAvailable") or 0,
                        }
                    )
                if commits:
                    feed.append({"r": node["nameWithOwner"], "c": commits})
                    total_commits += len(commits)

        feed.sort(key=lambda e: max(c["d"] for c in e["c"]), reverse=True)
        for entry in feed:
            entry["c"].sort(key=lambda c: c["d"], reverse=True)

        summary_url = os.environ.get("SUMMARY_LLM_URL", "").strip()
        summary_model = os.environ.get("SUMMARY_LLM_MODEL", "").strip()
        enrich_recent_with_summaries(client, summary_url, summary_model, feed)

    payload = render_feed(feed, since, now.isoformat())
    # Two output destinations by design (documented in SKILL.md):
    #   - /tmp/commit-watcher/feed-YYYY-MM-DD.md  → primary path the SKILL reads
    #   - ~/commit-watcher-YYYY-MM-DD.md           → mirror for direct inspection
    #     when running the script locally (Hermes cron pod's /tmp is ephemeral).
    out_file = OUTPUT_DIR / f"feed-{now.strftime('%Y-%m-%d')}.md"
    out_file.write_text(payload)

    home_file = Path.home() / f"commit-watcher-{now.strftime('%Y-%m-%d')}.md"
    home_file.write_text(payload)
    recent_count = sum(1 for entry in feed for c in entry["c"] if c["recent"])
    print(
        f"Wrote {out_file} ({total_commits} commits across {len(feed)} repos, "
        f"{recent_count} in last {RECENT_HOURS}h, {len(payload)} bytes)",
        file=sys.stderr,
    )
    print(f"Copied to {home_file}", file=sys.stderr)


if __name__ == "__main__":
    main()
