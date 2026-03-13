#!/usr/bin/env python3
"""Monitor dataRetrieval (R) and prepare a parity-sync PR payload."""

from __future__ import annotations

import datetime as dt
import json
import os
import pathlib
import sys
import urllib.error
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
STATE_PATH = ROOT / ".github" / "r-sync-state.json"
REPORT_PATH = ROOT / ".github" / "automation" / "r-sync-report.md"
PROMPT_PATH = ROOT / ".github" / "automation" / "r-parity-porting-prompt.md"

UPSTREAM_REPO = os.getenv("UPSTREAM_REPO", "DOI-USGS/dataRetrieval")
API_BASE = "https://api.github.com"


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def _request_json(url: str, token: str | None = None) -> dict:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "dataretrieval-jl-r-sync-agent",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"

    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GitHub API request failed: {url}\nHTTP {exc.code}\n{body}") from exc


def _load_state() -> dict:
    if not STATE_PATH.exists():
        return {
            "upstream_repo": UPSTREAM_REPO,
            "default_branch": "main",
            "last_processed_sha": "",
            "last_checked_utc": "",
            "last_sync_pr": "",
        }
    return json.loads(STATE_PATH.read_text(encoding="utf-8"))


def _save_state(state: dict) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")


def _set_output(key: str, value: str) -> None:
    out = os.getenv("GITHUB_OUTPUT")
    if out:
        with open(out, "a", encoding="utf-8") as fh:
            fh.write(f"{key}={value}\n")


def _short_sha(sha: str) -> str:
    return sha[:7] if sha else "none"


def _write_report(*,
                  upstream_repo: str,
                  default_branch: str,
                  previous_sha: str,
                  latest_sha: str,
                  compare_data: dict | None,
                  checked_utc: str) -> None:
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)

    lines: list[str] = []
    lines.append("# R Upstream Sync Report")
    lines.append("")
    lines.append(f"- Upstream repo: `{upstream_repo}`")
    lines.append(f"- Branch: `{default_branch}`")
    lines.append(f"- Checked at (UTC): `{checked_utc}`")
    lines.append(f"- Previous SHA: `{previous_sha or 'none'}`")
    lines.append(f"- Latest SHA: `{latest_sha}`")
    lines.append("")

    if compare_data is None:
        lines.append("No previous SHA is recorded yet, so this PR initializes sync state.")
        lines.append("")
    else:
        ahead_by = compare_data.get("ahead_by", 0)
        lines.append(f"- Upstream commits since previous SHA: `{ahead_by}`")
        lines.append("")

        commits = compare_data.get("commits", [])
        if commits:
            lines.append("## Commits")
            for commit in commits[:20]:
                sha = commit.get("sha", "")[:7]
                msg = commit.get("commit", {}).get("message", "").split("\n", 1)[0]
                author = commit.get("commit", {}).get("author", {}).get("name", "unknown")
                lines.append(f"- `{sha}` {msg} ({author})")
            if len(commits) > 20:
                lines.append(f"- ... and {len(commits) - 20} more")
            lines.append("")

        files = compare_data.get("files", [])
        if files:
            lines.append("## Changed Files")
            for item in files[:200]:
                status = item.get("status", "modified")
                filename = item.get("filename", "")
                lines.append(f"- `{status}` `{filename}`")
            if len(files) > 200:
                lines.append(f"- ... and {len(files) - 200} more")
            lines.append("")

    lines.append("## Porting Checklist")
    lines.append("- [ ] Review upstream R changes in this report.")
    lines.append("- [ ] Port user-facing behavior from R to Julia sources in `src/`.")
    lines.append("- [ ] Update tests in `test/` for new/changed behavior.")
    lines.append("- [ ] Update docs in `docs/src/` and README where needed.")
    lines.append("- [ ] Run package tests and summarize outcomes in this PR.")
    lines.append("")

    REPORT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_porting_prompt(upstream_repo: str, previous_sha: str, latest_sha: str) -> None:
    PROMPT_PATH.parent.mkdir(parents=True, exist_ok=True)
    text = f"""# Porting Prompt For Coding Agent

You are porting upstream changes from `{upstream_repo}` (R dataRetrieval) into this Julia repository.

## Scope
- Previous upstream SHA: `{previous_sha or 'none'}`
- Latest upstream SHA: `{latest_sha}`
- Source of truth for changed files and commits: `.github/automation/r-sync-report.md`

## Required Work
1. Port behavior changes from R into Julia implementation under `src/`.
2. Add or update tests under `test/`.
3. Update docs in `docs/src/` and `README.md`.
4. Keep Julia API naming conventions and avoid introducing R-only wrappers unless explicitly required.
5. Run tests and include key results.

## Constraints
- Prefer minimal, focused patches.
- Preserve existing public APIs unless upstream parity requires an addition/change.
- Do not revert unrelated local changes.
"""
    PROMPT_PATH.write_text(text, encoding="utf-8")


def main() -> int:
    gh_token = os.getenv("GITHUB_TOKEN") or os.getenv("GH_TOKEN")
    state = _load_state()

    owner, repo = UPSTREAM_REPO.split("/", 1)
    repo_info = _request_json(f"{API_BASE}/repos/{owner}/{repo}", token=gh_token)
    default_branch = repo_info.get("default_branch", "main")

    latest_commit = _request_json(
        f"{API_BASE}/repos/{owner}/{repo}/commits/{urllib.parse.quote(default_branch)}",
        token=gh_token,
    )
    latest_sha = latest_commit.get("sha", "")
    if not latest_sha:
        raise RuntimeError("Unable to determine latest upstream SHA")

    previous_sha = state.get("last_processed_sha", "")
    checked_utc = _utc_now()

    state["upstream_repo"] = UPSTREAM_REPO
    state["default_branch"] = default_branch
    state["last_checked_utc"] = checked_utc

    has_updates = bool(previous_sha) and previous_sha != latest_sha
    initializing = not bool(previous_sha)

    compare_data = None
    if has_updates:
        compare_data = _request_json(
            f"{API_BASE}/repos/{owner}/{repo}/compare/{previous_sha}...{latest_sha}",
            token=gh_token,
        )

    if has_updates or initializing:
        _write_report(
            upstream_repo=UPSTREAM_REPO,
            default_branch=default_branch,
            previous_sha=previous_sha,
            latest_sha=latest_sha,
            compare_data=compare_data,
            checked_utc=checked_utc,
        )
        _write_porting_prompt(UPSTREAM_REPO, previous_sha, latest_sha)
        state["last_processed_sha"] = latest_sha
        _save_state(state)

    _set_output("has_updates", "true" if (has_updates or initializing) else "false")
    _set_output("initializing", "true" if initializing else "false")
    _set_output("latest_sha", latest_sha)
    _set_output("latest_sha_short", _short_sha(latest_sha))
    _set_output("previous_sha", previous_sha)

    if has_updates:
        print(f"Detected updates: {previous_sha} -> {latest_sha}")
    elif initializing:
        print(f"Initialized state at upstream SHA: {latest_sha}")
    else:
        print("No upstream updates detected.")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover
        print(str(exc), file=sys.stderr)
        raise
