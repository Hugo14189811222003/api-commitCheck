"""
FastAPI server for commit risk scoring using the trained Random Forest model.

Usage:
    uvicorn server:app --reload

Endpoint:
    POST /score-commit
    Body: {
        "repo_path": "/path/to/git/repo",
        "commit_sha": "a1b2c3d4",
        "ai_used": 0,           # optional
        "ai_tokens_in": 0,      # optional
        "ai_tokens_out": 0,     # optional
        "ai_agent_turns": 0,    # optional
        "human_edit_ratio": 1.0 # optional
    }
"""

import os
import re
import subprocess
import tempfile
import shutil
import joblib
import pandas as pd
from datetime import datetime
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional, Union

# Model paths
MODEL_PATH = "model/pr_scorer.pkl"
COLUMNS_PATH = "model/feature_columns.pkl"

# Load model and feature columns
if not os.path.exists(MODEL_PATH):
    raise RuntimeError(f"Model not found at '{MODEL_PATH}'. Run train.py first.")

model = joblib.load(MODEL_PATH)
feature_cols = joblib.load(COLUMNS_PATH)

app = FastAPI(title="Commit Risk Scorer", description="Score git commits for bug-inducing risk", version="1.0.0")

class ScoreRequest(BaseModel):
    repo_path: Optional[str] = None
    github_url: Optional[str] = None
    commit_sha: str
    ai_used: Optional[int] = 0
    ai_tokens_in: Optional[int] = 0
    ai_tokens_out: Optional[int] = 0
    ai_agent_turns: Optional[int] = 0
    human_edit_ratio: Optional[float] = 1.0

class ScoreResponse(BaseModel):
    risk_score: float
    risk_label: str
    confidence: float
    top_contributors: dict
    commit_info: dict

# ----------------------------------------------------------------
# GitHub repo handling
# ----------------------------------------------------------------

def prepare_repo(repo_path: Optional[str] = None, github_url: Optional[str] = None) -> str:
    """
    Prepare a repository for analysis. Either use existing local path or clone GitHub repo.
    Returns the local path to use.
    """
    if repo_path:
        if not os.path.exists(repo_path):
            raise HTTPException(status_code=400, detail=f"Local repository path does not exist: {repo_path}")
        return repo_path

    if github_url:
        # Extract owner/repo from GitHub URL
        match = re.search(r'github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$', github_url)
        if not match:
            raise HTTPException(status_code=400, detail="Invalid GitHub URL format")

        owner, repo = match.groups()
        clone_url = f"https://github.com/{owner}/{repo}.git"

        # Create temporary directory
        temp_dir = tempfile.mkdtemp(prefix="commit_scorer_")

        try:
            # Clone the repository
            result = subprocess.run(
                ["git", "clone", "--quiet", clone_url, temp_dir],
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )
            if result.returncode != 0:
                raise HTTPException(status_code=400, detail=f"Failed to clone repository: {result.stderr}")

            return temp_dir
        except subprocess.TimeoutExpired:
            shutil.rmtree(temp_dir, ignore_errors=True)
            raise HTTPException(status_code=408, detail="Repository cloning timed out")
        except Exception as e:
            shutil.rmtree(temp_dir, ignore_errors=True)
            raise HTTPException(status_code=500, detail=f"Failed to prepare repository: {str(e)}")

    raise HTTPException(status_code=400, detail="Either repo_path or github_url must be provided")

def git(repo_path: str, *args) -> str:
    result = subprocess.run(
        ["git", "-C", repo_path, *args],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise HTTPException(status_code=400, detail=f"Git command failed: {' '.join(args)}")
    return result.stdout.strip()

def parse_ts(ts: str) -> datetime:
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%SZ"):
        try:
            return datetime.strptime(ts[:19], fmt)
        except Exception:
            continue
    return datetime.min

def hour_of(ts: str) -> int:
    dt = parse_ts(ts)
    return dt.hour if dt != datetime.min else -1

def weekday_of(ts: str) -> int:
    dt = parse_ts(ts)
    return dt.weekday() if dt != datetime.min else -1

def hours_between(start: str, end: str) -> float | None:
    a, b = parse_ts(start), parse_ts(end)
    if a == datetime.min or b == datetime.min:
        return None
    return round(abs((b - a).total_seconds() / 3600), 2)

# ----------------------------------------------------------------
# Feature extraction (adapted from predict_local.py)
# ----------------------------------------------------------------

def extract_features(repo_path: str, commit_sha: str) -> tuple[dict, dict]:
    """
    Extract scoring features from any commit.
    """
    # Resolve full SHA
    full_sha = git(repo_path, "rev-parse", commit_sha)
    if not full_sha:
        raise HTTPException(status_code=404, detail=f"Commit '{commit_sha}' not found in {repo_path}")

    # Get parents
    parents_raw = git(repo_path, "log", "-1", "--format=%P", full_sha)
    parents = parents_raw.strip().split()

    if len(parents) == 0:
        raise HTTPException(status_code=400, detail="This is the initial commit — nothing to diff against.")

    # Diff base: for merge commits use both parents, for regular use parent^
    if len(parents) >= 2:
        diff_base = parents[0]   # base branch
        diff_tip = parents[1]   # PR branch tip
        is_merge = True
    else:
        diff_base = parents[0]   # previous commit
        diff_tip = full_sha
        is_merge = False

    # --- Commit metadata ---
    committed_at = git(repo_path, "log", "-1", "--format=%ai", full_sha)
    subject = git(repo_path, "log", "-1", "--format=%s", full_sha)
    author_email = git(repo_path, "log", "-1", "--format=%ae", full_sha)
    committed_dt = parse_ts(committed_at)

    pr_match = re.search(r"#(\d+)", subject)
    pr_number = int(pr_match.group(1)) if pr_match else -1

    # --- Diff stats ---
    stat = git(repo_path, "diff", "--shortstat", diff_base, diff_tip)
    lines_added = int(m.group(1)) if (m := re.search(r"(\d+) insertion", stat)) else 0
    lines_deleted = int(m.group(1)) if (m := re.search(r"(\d+) deletion", stat)) else 0
    files_changed = int(m.group(1)) if (m := re.search(r"(\d+) file", stat)) else 0
    total_churn = lines_added + lines_deleted
    churn_ratio = round(lines_added / (total_churn + 1), 3)

    # --- Changed files ---
    files_raw = git(repo_path, "diff", "--name-only", diff_base, diff_tip)
    changed_files = [f.strip() for f in files_raw.splitlines() if f.strip()]
    subsystems = len(set(f.split("/")[0] for f in changed_files if "/" in f))

    # --- Commits in range ---
    if is_merge:
        log = git(repo_path, "log", f"{diff_base}..{diff_tip}", "--format=%H|||%ae|||%ai|||%s")
    else:
        log = git(repo_path, "log", "-1", "--format=%H|||%ae|||%ai|||%s", full_sha)

    commits = []
    for line in log.splitlines():
        parts = line.split("|||")
        if len(parts) < 4:
            continue
        sha, email, ts, msg = parts
        commits.append({
            "sha": sha.strip(),
            "email": email.strip(),
            "ts": ts.strip(),
            "hour": hour_of(ts.strip()),
            "msg": msg.strip(),
        })

    commit_hours = [c["hour"] for c in commits]
    unique_authors = len(set(c["email"] for c in commits))

    # --- Timing ---
    first_commit_ts = commits[-1]["ts"] if commits else committed_at
    time_to_merge_hours = hours_between(first_commit_ts, committed_at)

    # --- Context ---
    branch_ref = git(repo_path, "log", "-1", "--format=%D", diff_tip)
    is_hotfix = int(bool(re.search(
        r"\b(hotfix|patch|fix)\b", branch_ref + subject, re.IGNORECASE
    )))

    features = {
        # --- Size ---
        "lines_added": lines_added,
        "lines_deleted": lines_deleted,
        "changed_files": files_changed,
        "total_churn": total_churn,
        "churn_ratio": churn_ratio,

        # --- Timing ---
        "time_to_merge_hours": time_to_merge_hours,
        "time_in_review_hours": None,
        "first_response_hours": None,
        "pr_open_hour": hour_of(first_commit_ts),
        "pr_merged_hour": hour_of(committed_at),
        "pr_merged_weekday": weekday_of(committed_at),
        "is_friday_merge": int(weekday_of(committed_at) == 4),

        # --- Commit signals ---
        "commit_count": len(commits),
        "has_late_night_commit": int(any(h >= 22 or h <= 4 for h in commit_hours if h >= 0)),
        "earliest_commit_hour": min(commit_hours) if commit_hours else -1,
        "latest_commit_hour": max(commit_hours) if commit_hours else -1,
        "commit_hour_std": round(float(pd.Series(commit_hours).std()), 2) if len(commit_hours) > 1 else 0.0,

        # --- Review signals (not available locally) ---
        "review_comment_count": 0,
        "comments_count": 0,
        "reviewer_count": 0,
        "approvals_count": 0,
        "pr_iteration_count": 0,

        # --- Context ---
        "is_hotfix": is_hotfix,
        "unique_authors": unique_authors,
        "subsystems_changed": subsystems,

        # --- AI usage (will be set from request) ---
        "ai_used": 0,
        "ai_tokens_in": 0,
        "ai_tokens_out": 0,
        "ai_total_tokens": 0,
        "ai_token_ratio": 0.0,
        "ai_agent_turns": 0,
        "human_edit_ratio": 1.0,
    }

    meta = {
        "pr_number": pr_number,
        "full_sha": full_sha,
        "subject": subject,
        "author": author_email,
        "committed_at": committed_at,
        "is_merge": is_merge,
        "commit_count": len(commits),
        "changed_files": changed_files[:5],
        "total_files": len(changed_files),
    }

    return features, meta

# ----------------------------------------------------------------
# Scoring
# ----------------------------------------------------------------

def score_commit(features: dict) -> tuple[float, dict]:
    df = pd.DataFrame([features])

    for col in feature_cols:
        if col not in df.columns:
            df[col] = 0
    df = df[feature_cols].fillna(0)

    probability = model.predict_proba(df)[0]
    risk_pct = round(float(probability[1]) * 100, 1)

    contributions = {
        feat: {
            "value": round(float(df[feat].iloc[0]), 4),
            "importance": round(float(imp), 4),
        }
        for feat, imp in zip(feature_cols, model.feature_importances_)
    }

    top_contributors = dict(
        sorted(contributions.items(), key=lambda x: x[1]["importance"], reverse=True)[:5]
    )

    return risk_pct, top_contributors

# ----------------------------------------------------------------
# API Endpoints
# ----------------------------------------------------------------

@app.post("/score-commit", response_model=ScoreResponse)
async def score_commit_endpoint(request: ScoreRequest):
    """
    Score a git commit for bug-inducing risk.

    - **repo_path**: Absolute path to a local git repository (optional if github_url provided)
    - **github_url**: GitHub repository URL (optional if repo_path provided)
    - **commit_sha**: The commit SHA to score
    - **ai_used**: Whether AI was used (0 or 1)
    - **ai_tokens_in**: Input tokens used by AI
    - **ai_tokens_out**: Output tokens used by AI
    - **ai_agent_turns**: Number of AI agent turns
    - **human_edit_ratio**: Ratio of human edits (0.0 to 1.0)
    """
    temp_repo = None
    try:
        # Prepare repository (clone if needed)
        actual_repo_path = prepare_repo(request.repo_path, request.github_url)
        if request.github_url and not request.repo_path:
            temp_repo = actual_repo_path

        # Extract features
        features, meta = extract_features(actual_repo_path, request.commit_sha)

        # Override AI features from request
        features["ai_used"] = request.ai_used
        features["ai_tokens_in"] = request.ai_tokens_in
        features["ai_tokens_out"] = request.ai_tokens_out
        features["ai_total_tokens"] = request.ai_tokens_in + request.ai_tokens_out
        features["ai_token_ratio"] = request.ai_tokens_out / (request.ai_tokens_in + request.ai_tokens_out + 1)
        features["ai_agent_turns"] = request.ai_agent_turns
        features["human_edit_ratio"] = request.human_edit_ratio

        # Score the commit
        risk_pct, top_contributors = score_commit(features)

        # Determine risk label
        risk_label = "🔴 HIGH" if risk_pct >= 60 else "🟡 MEDIUM" if risk_pct >= 30 else "🟢 LOW"

        # Get confidence (max probability)
        df = pd.DataFrame([features])
        for col in feature_cols:
            if col not in df.columns:
                df[col] = 0
        df = df[feature_cols].fillna(0)
        probability = model.predict_proba(df)[0]
        confidence = round(float(max(probability)) * 100, 1)

        return ScoreResponse(
            risk_score=risk_pct,
            risk_label=risk_label,
            confidence=confidence,
            top_contributors=top_contributors,
            commit_info=meta
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
    finally:
        # Clean up temporary repository
        if temp_repo and os.path.exists(temp_repo):
            shutil.rmtree(temp_repo, ignore_errors=True)

@app.get("/")
async def root():
    return {"message": "Commit Risk Scorer API", "version": "1.0.0"}

@app.get("/health")
async def health():
    return {"status": "healthy"}