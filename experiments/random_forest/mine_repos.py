"""
mine_repos.py — Clone OSS repos and extract PR + commit data locally.

Uses local git commands for everything possible (no rate limits, fast).
Only touches GitHub API for PR metadata that git can't provide
(reviewer count, approval count, review timestamps).

Produces:
    data/raw/pull_requests.csv
    data/raw/commits.csv

Usage:
    python scripts/mine_repos.py

Add or remove repos from the REPOS list at the top of this file.
"""

import os
import re
import csv
import time
import subprocess
import requests
import pandas as pd
from datetime import datetime
from dotenv import load_dotenv
import multiprocessing

load_dotenv()

GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")

# ----------------------------------------------------------------
# Repos to mine — add as many as you want
# Choosing a good repo: many merged PRs, active development, good commit hygiene (descriptive messages).
# Format: (github_owner, repo_name)
# ----------------------------------------------------------------
REPOS = [
        ("hooram",        "ownphotos-frontend"),
        ("documize",      "documize-community"),
            ("KSJaay",        "Lunalytics"),
    ("django",        "django"),
    ("dockpeek",      "dockpeek"),
    ("soumyajit4419", "Portfolio"),
    ("guardian",      "frontend"),
    ("blockscout",    "frontend"),
    ("SillyTavern",   "SillyTavern"),
    ("journiv",       "journiv-app"),
    ("cloudreve",     "frontend"),
        ("GitbookIO",     "gitbook"),
        ("pancakeswap",   "pancake-frontend"),
        ("EmulatorJS",    "EmulatorJS"),
            ("libre-tube",    "LibreTube"),
    # ("facebook",      "react"),
    # ("microsoft",     "vscode"),
    ("pallets",       "flask"),
    # ("apache",        "airflow"),
    # ("psf",           "requests"),
    # ("scikit-learn",  "scikit-learn"),
]

# ----------------------------------------------------------------
# Config
# ----------------------------------------------------------------
CLONE_DIR      = os.path.abspath("data/clones")
PR_OUTPUT      = os.path.abspath("data/raw/pull_requests.csv")
COMMIT_OUTPUT  = os.path.abspath("data/raw/commits.csv")

# How many merged PRs to extract per repo
MAX_PRS_PER_REPO = 500

# Only use GitHub API for review metadata if token is provided
USE_GITHUB_API = bool(GITHUB_TOKEN)

GH_HEADERS = {
    "Authorization": f"Bearer {GITHUB_TOKEN}",
    "Accept": "application/vnd.github+json",
}


# ----------------------------------------------------------------
# Git helpers — all run as local subprocess commands
# ----------------------------------------------------------------

def git(repo_path: str, *args) -> str:
    """Run a git command in a repo and return stdout."""
    result = subprocess.run(
        ["git", "-C", repo_path, *args],
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def clone_or_update(owner: str, repo: str) -> str:
    """Clone repo if not present, otherwise pull latest."""
    os.makedirs(CLONE_DIR, exist_ok=True)
    repo_path = os.path.join(CLONE_DIR, f"{owner}__{repo}")

    if os.path.exists(repo_path):
        print(f"  Updating {owner}/{repo}...")
        git(repo_path, "fetch", "--quiet")
        git(repo_path, "pull", "--quiet")
    else:
        url = f"https://github.com/{owner}/{repo}.git"
        print(f"  Cloning {url}...")
        subprocess.run(["git", "clone", "--quiet", url, repo_path], check=True)

    return repo_path


def get_merge_commits(repo_path: str, max_count: int) -> list[dict]:
    """
    Extract merge commits from git log, skipping the most recent 6 months.

    We skip recent PRs because the 180-day bug-fix window hasn't closed yet —
    a PR merged last week can't have a bug fix commit yet, so it would always
    be labeled clean (0) incorrectly.

    We fetch from git log with --before to anchor to safe historical data.
    """
    from datetime import datetime, timedelta

    # Only consider PRs merged before 6 months ago
    cutoff = (datetime.now() - timedelta(days=180)).strftime("%Y-%m-%d")

    log = git(
        repo_path,
        "log",
        "--merges",
        f"--before={cutoff}",
        f"--max-count={max_count * 3}",   # fetch extra since some won't have PR numbers
        "--format=%H|||%P|||%ae|||%ai|||%s"
    )

    merges = []
    for line in log.splitlines():
        parts = line.split("|||")
        if len(parts) < 5:
            continue

        sha, parents, author_email, timestamp, subject = parts
        parent_shas = parents.strip().split()

        if len(parent_shas) < 2:
            continue  # not a real merge commit

        # Extract PR number from subject (GitHub format: "Merge pull request #123")
        pr_match = re.search(r"#(\d+)", subject)
        if not pr_match:
            continue

        pr_number = int(pr_match.group(1))

        merges.append({
            "sha":          sha.strip(),
            "parent_main":  parent_shas[0],   # the base branch parent
            "parent_pr":    parent_shas[1],   # the PR branch tip
            "author_email": author_email.strip(),
            "merged_at":    timestamp.strip(),
            "subject":      subject.strip(),
            "pr_number":    pr_number,
        })

        if len(merges) >= max_count:
            break

    return merges


def get_commits_in_pr(repo_path: str, parent_main: str, parent_pr: str) -> list[dict]:
    """
    Get all commits that are in the PR branch but not in main.
    This is the range: parent_main..parent_pr
    """
    log = git(
        repo_path,
        "log",
        f"{parent_main}..{parent_pr}",
        "--format=%H|||%ae|||%ai|||%s"
    )

    commits = []
    for line in log.splitlines():
        parts = line.split("|||")
        if len(parts) < 4:
            continue

        sha, author_email, timestamp, message = parts
        hour    = hour_of_git_timestamp(timestamp.strip())
        commits.append({
            "commit_hash":   sha.strip(),
            "author_email":  author_email.strip(),
            "committed_at":  timestamp.strip(),
            "message":       message.strip()[:120],
            "commit_hour":   hour,
            "is_late_night": int(hour >= 22 or hour <= 4),
        })

    return commits


def get_diff_stats(repo_path: str, parent_main: str, parent_pr: str) -> dict:
    """
    Get lines added/deleted and files changed for the entire PR diff.
    Uses git diff --stat between the base and PR tip.
    """
    # --shortstat gives: "X files changed, Y insertions(+), Z deletions(-)"
    stat = git(repo_path, "diff", "--shortstat", parent_main, parent_pr)

    lines_added   = 0
    lines_deleted = 0
    files_changed = 0

    match_files = re.search(r"(\d+) file", stat)
    match_add   = re.search(r"(\d+) insertion", stat)
    match_del   = re.search(r"(\d+) deletion", stat)

    if match_files: files_changed = int(match_files.group(1))
    if match_add:   lines_added   = int(match_add.group(1))
    if match_del:   lines_deleted = int(match_del.group(1))

    return {
        "files_changed": files_changed,
        "lines_added":   lines_added,
        "lines_deleted": lines_deleted,
    }


def get_changed_files(repo_path: str, parent_main: str, parent_pr: str) -> list[str]:
    """Get the list of files changed in this PR."""
    output = git(repo_path, "diff", "--name-only", parent_main, parent_pr)
    return [f.strip() for f in output.splitlines() if f.strip()]


def get_file_churn_history(repo_path: str, filepath: str, before_sha: str) -> dict:
    """
    How many times has this file been changed historically?
    Used as a proxy for 'past bugs in this file'.
    """
    log = git(
        repo_path,
        "log",
        before_sha,
        "--follow",
        "--format=%H",
        "--",
        filepath,
    )
    commits = [l for l in log.splitlines() if l.strip()]
    return {
        "file_commit_count": len(commits),
        "file_unique_authors": len(set(
            git(repo_path, "log", "--format=%ae", "--", filepath).splitlines()
        ))
    }


def get_subsystems(files: list[str]) -> int:
    """Count unique top-level directories touched (subsystem proxy)."""
    return len(set(
        f.split("/")[0] for f in files if "/" in f
    ))


BUG_KEYWORDS = re.compile(
    r"\b(fix(es|ed|ing)?|bug|hotfix|revert|regression|broken|crash|error|issue|defect)\b",
    re.IGNORECASE
)


def get_commit_messages(repo_path: str, parent_main: str, parent_pr: str) -> list[str]:
    """Get all commit messages inside a PR (not the merge commit subject)."""
    log = git(repo_path, "log", f"{parent_main}..{parent_pr}", "--format=%s")
    return [l.strip() for l in log.splitlines() if l.strip()]


def get_later_non_merge_commits(
    repo_path: str, since_sha: str, merged_at: str, days: int = 180
) -> list[dict]:
    """
    Get non-merge commits that come after since_sha AND within `days` days
    of the merged_at timestamp.

    Uses --after and --before with absolute dates derived from merged_at so
    this works correctly for historical PRs, not just recent ones.
    """
    merged_dt  = parse_git_timestamp(merged_at)
    after_date = merged_dt.strftime("%Y-%m-%d")

    # Compute the end of the window as merged_dt + days
    from datetime import timedelta
    before_dt   = merged_dt + timedelta(days=days)
    before_date = before_dt.strftime("%Y-%m-%d")

    log = git(
        repo_path,
        "log",
        f"{since_sha}..HEAD",
        "--no-merges",
        "--format=%H|||%ai|||%s",
        f"--after={after_date}",
        f"--before={before_date}",
    )
    commits = []
    for line in log.splitlines():
        parts = line.split("|||")
        if len(parts) < 3:
            continue
        sha, timestamp, subject = parts[0].strip(), parts[1].strip(), parts[2].strip()
        if not sha:
            continue
        commits.append({
            "sha":       sha,
            "timestamp": timestamp,
            "subject":   subject,
        })
    return commits


def auto_label(
    repo_path:  str,
    pr_number:  int,
    merge_sha:  str,
    merged_at:  str,
    all_merges: list[dict],
) -> int:
    """
    Automatically label a PR as buggy (1) or clean (0).

    Uses three signals, in order of reliability:

    Signal 1 — Direct revert
        A later merge commit subject contains "Revert" and this PR number.
        Most reliable signal — unambiguous.

    Signal 2 — Later non-merge commits touch the same files with bug keywords
        Individual commit messages (not merge subjects) are much more
        descriptive than "Merge pull request #X from user/patch-1".
        If a later commit says "Fix crash in login" and touches the same
        files this PR touched, this PR likely introduced the bug.

    Signal 3 — PR's own commits mention fixing a bug
        If the commits inside this PR say "fix X" or "bug in Y", this PR
        is itself a bug fix — meaning some earlier PR introduced the bug.
        We label this PR clean (it's the fix, not the cause), but the
        signal is used to find the buggy PR upstream via file overlap.
    """
    # Files that appear in almost every PR — useless for overlap matching
    NOISE_FILES = {
        "AUTHORS", "CHANGELOG", "CHANGELOG.md", "CHANGELOG.rst",
        "CHANGES", "CHANGES.md", "CHANGES.rst", "HISTORY.md",
        "CONTRIBUTORS", "CONTRIBUTORS.md", "CONTRIBUTORS.txt",
        "NEWS", "RELEASE", "VERSION",
    }

    merged_dt = parse_git_timestamp(merged_at)
    raw_files = set(get_changed_files(repo_path, merge_sha + "^1", merge_sha + "^2"))

    # Strip noise files and docs — only match on actual source files
    pr_files = {
        f for f in raw_files
        if os.path.basename(f) not in NOISE_FILES
        and not f.endswith((".txt", ".rst", ".md"))
    }

    if not pr_files:
        return 0

    # --- Signal 1: Direct revert of this PR number ---
    for later_merge in all_merges:
        later_dt = parse_git_timestamp(later_merge["merged_at"])
        if later_dt <= merged_dt:
            continue
        if (later_dt - merged_dt).days > 180:
            break
        subject = later_merge["subject"].lower()
        if "revert" in subject and str(pr_number) in later_merge["subject"]:
            return 1

    # --- Signal 2: Later non-merge commits with bug keywords touching same files ---
    later_commits = get_later_non_merge_commits(repo_path, merge_sha, merged_at, days=180)
    for commit in later_commits:
        later_dt = parse_git_timestamp(commit["timestamp"])
        if (later_dt - merged_dt).days > 180:
            continue

        full_message = commit['subject']
        if not BUG_KEYWORDS.search(full_message):
            continue

        # Check if this fix commit touches any of the same files
        changed = git(
            repo_path,
            "diff-tree", "--no-commit-id", "-r", "--name-only", commit["sha"]
        )
        fix_files = set(f.strip() for f in changed.splitlines() if f.strip())

        if pr_files & fix_files:
            return 1

    return 0


# ----------------------------------------------------------------
# Optional GitHub API — only for review metadata
# ----------------------------------------------------------------

def fetch_review_metadata(owner: str, repo: str, pr_number: int) -> dict:
    """
    Fetch review metadata from GitHub API.
    Returns empty defaults if API is unavailable or rate limited.
    """
    if not USE_GITHUB_API:
        return {
            "reviewer_count":    -1,
            "approvals_count":   -1,
            "pr_iteration_count": -1,
            "first_review_at":   None,
            "time_in_review_hours": None,
        }

    try:
        url     = f"https://api.github.com/repos/{owner}/{repo}/pulls/{pr_number}/reviews"
        resp    = requests.get(url, headers=GH_HEADERS, timeout=10)
        resp.raise_for_status()
        reviews = resp.json()

        reviewers  = set(r["user"]["login"] for r in reviews if r.get("user"))
        approvals  = sum(1 for r in reviews if r["state"] == "APPROVED")
        first_review = reviews[0].get("submitted_at") if reviews else None

        return {
            "reviewer_count":       len(reviewers),
            "approvals_count":      approvals,
            "pr_iteration_count":   -1,
            "first_review_at":      first_review,
        }
    except Exception:
        return {
            "reviewer_count":    -1,
            "approvals_count":   -1,
            "pr_iteration_count": -1,
            "first_review_at":   None,
        }


# ----------------------------------------------------------------
# Multiprocessing helper
# ----------------------------------------------------------------

def process_merge(owner: str, repo: str, repo_path: str, merge: dict, all_merges: list[dict], i: int) -> tuple[dict, list[dict]]:
    pr_number   = merge["pr_number"]
    merge_sha   = merge["sha"]
    parent_main = merge["parent_main"]
    parent_pr   = merge["parent_pr"]
    merged_at   = merge["merged_at"]

    # --- Diff stats ---
    diff_stats = get_diff_stats(repo_path, parent_main, parent_pr)

    # --- Commits ---
    commits = get_commits_in_pr(repo_path, parent_main, parent_pr)

    commit_hours = [c["commit_hour"] for c in commits]
    total_churn = diff_stats["lines_added"] + diff_stats["lines_deleted"]

    commit_rows_local = []
    for c in commits:
        commit_rows_local.append({
            "repo":          f"{owner}/{repo}",
            "pr_number":     f"{owner}/{repo}#{pr_number}",
            **c,
            "lines_added":   diff_stats["lines_added"],
            "lines_deleted": diff_stats["lines_deleted"],
        })

    # --- Changed files ---
    changed_files = get_changed_files(repo_path, parent_main, parent_pr)
    subsystems    = get_subsystems(changed_files)

    # --- Auto label ---
    label = auto_label(repo_path, pr_number, merge_sha, merged_at, all_merges[i+1:])

    # --- Review metadata (GitHub API, optional) ---
    review_meta = fetch_review_metadata(owner, repo, pr_number)

    # --- Time signals ---
    merged_hour    = hour_of_git_timestamp(merged_at)
    merged_weekday = parse_git_timestamp(merged_at).weekday()

    pr_row = {
        "repo":                  f"{owner}/{repo}",
        "pr_number":             f"{owner}/{repo}#{pr_number}",
        "merged_at":             merged_at,
        "pr_merged_hour":        merged_hour,
        "pr_merged_weekday":     merged_weekday,
        "is_friday_merge":       int(merged_weekday == 4),

        # Size
        "lines_added":           diff_stats["lines_added"],
        "lines_deleted":         diff_stats["lines_deleted"],
        "changed_files":         diff_stats["files_changed"],
        "total_churn":           total_churn,
        "churn_ratio":           round(diff_stats["lines_added"] / (total_churn + 1), 3),

        # Commit signals
        "commit_count":          len(commits),
        "unique_authors":        len(set(c["author_email"] for c in commits)),
        "has_late_night_commit": int(any(c["is_late_night"] for c in commits)),
        "earliest_commit_hour":  min(commit_hours) if commit_hours else -1,
        "latest_commit_hour":    max(commit_hours) if commit_hours else -1,
        "commit_hour_std":       round(pd.Series(commit_hours).std(), 2) if len(commit_hours) > 1 else 0.0,

        # Diffusion
        "subsystems_changed":    subsystems,

        # Review (from GitHub API if available)
        "reviewer_count":        review_meta["reviewer_count"],
        "approvals_count":       review_meta["approvals_count"],
        "pr_iteration_count":    review_meta["pr_iteration_count"],

        # Context
        "is_hotfix":             int(bool(re.search(
            r"\b(hotfix|patch|fix)\b", merge["subject"], re.IGNORECASE
        ))),

        # AI usage — filled in manually later via ai_log.csv
        "ai_used":               0,
        "ai_tokens_in":          0,
        "ai_tokens_out":         0,
        "ai_agent_turns":        0,
        "human_edit_ratio":      1.0,

        # Label (auto-detected)
        "label":                 label,
    }

    return pr_row, commit_rows_local

def hour_of_git_timestamp(ts: str) -> int:
    """Extract hour from git log timestamp: '2023-04-12 14:32:01 +0000'"""
    try:
        return datetime.strptime(ts[:19], "%Y-%m-%d %H:%M:%S").hour
    except Exception:
        return -1


def parse_git_timestamp(ts: str) -> datetime:
    try:
        return datetime.strptime(ts[:19], "%Y-%m-%d %H:%M:%S")
    except Exception:
        return datetime.min


def hours_between_git(start: str, end: str) -> float | None:
    try:
        a = datetime.strptime(start[:19], "%Y-%m-%d %H:%M:%S")
        b = datetime.strptime(end[:19],   "%Y-%m-%d %H:%M:%S")
        return round(abs((b - a).total_seconds() / 3600), 2)
    except Exception:
        return None


# ----------------------------------------------------------------
# Main mining loop
# ----------------------------------------------------------------

def mine_repo(owner: str, repo: str) -> tuple[list[dict], list[dict]]:
    print(f"\n{'='*50}")
    print(f"Mining {owner}/{repo}")
    print(f"{'='*50}")

    repo_path = clone_or_update(owner, repo)

    print(f"  Extracting merge commits...")
    all_merges = get_merge_commits(repo_path, MAX_PRS_PER_REPO)
    print(f"  Found {len(all_merges)} merged PRs")

    pr_rows     = []
    commit_rows = []

    with multiprocessing.Pool() as pool:
        results = pool.starmap(process_merge, [(owner, repo, repo_path, merge, all_merges, i) for i, merge in enumerate(all_merges)])

    for pr_row, commit_rows_local in results:
        pr_rows.append(pr_row)
        commit_rows.extend(commit_rows_local)

    buggy = sum(1 for p in pr_rows if p["label"] == 1)
    print(f"\n  Done. {len(pr_rows)} PRs — {buggy} buggy ({buggy/max(len(pr_rows),1)*100:.1f}%)")

    return pr_rows, commit_rows


def main():
    os.makedirs("data/raw", exist_ok=True)

    all_prs     = []
    all_commits = []

    for owner, repo in REPOS:
        try:
            prs, commits = mine_repo(owner, repo)
            all_prs.extend(prs)
            all_commits.extend(commits)
        except Exception as e:
            print(f"\nERROR mining {owner}/{repo}: {e}")
            continue

    pr_df     = pd.DataFrame(all_prs)
    commit_df = pd.DataFrame(all_commits)

    pr_df.to_csv(PR_OUTPUT, index=False)
    commit_df.to_csv(COMMIT_OUTPUT, index=False)

    if len(pr_df) == 0:
        total_buggy = 0
    else:
        total_buggy = pr_df["label"].sum() if "label" in pr_df.columns else 0
    print(f"\n{'='*50}")
    print(f"DONE")
    print(f"Total PRs:    {len(pr_df):,}")
    print(f"Total commits:{len(commit_df):,}")
    print(f"Buggy PRs:    {int(total_buggy)} ({total_buggy/len(pr_df)*100:.1f}%)" if len(pr_df) > 0 else "Buggy PRs:    0 (0.0%)")
    print(f"\nSaved to:")
    print(f"  {PR_OUTPUT}")
    print(f"  {COMMIT_OUTPUT}")
    print(f"\nNext: python scripts/extract_features.py")


if __name__ == "__main__":
    main()