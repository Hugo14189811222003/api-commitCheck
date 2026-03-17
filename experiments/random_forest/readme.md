# PR Scorer

A machine learning model that scores GitHub pull requests for bug risk (0–100%).

Trained on data mined from real OSS repositories using local git commands — no API rate limits, no manual labeling. PRs are automatically labeled as buggy or clean by detecting reverts and bug-fix commits that touch the same files within 90 days of merge.

Features come from three sources:
- Local git history (PR size, commit timing, churn, diffusion)
- GitHub API, optional (reviewer count, approval count)
- Your manual AI usage log (tokens in/out, agent turns, human edit ratio)

---

# Run

```bash
python mine_repos.py && python extract_features.py && python train.py &&  python predict_local.py [repo_path] [commit_hash]
```

# Basic API usage

```bash
curl -X POST http://127.0.0.1:8000/score-commit \
  -H "Content-Type: application/json" \
  -d '{
    "github_url": "https://github.com/OWNER/REPO",
    "commit_sha": "a1b2c3d4e5f6g7h8i9j0"
  }'
```

---

## Setup

### 1. Install dependencies
```bash
pip install -r requirements.txt
```

### 2. Configure environment
```bash
cp .env.example .env
```

A GitHub token is optional. Without one the script still runs fully — it just skips reviewer and approval count features. If you do add a token, go to github.com → Settings → Developer Settings → Personal Access Tokens and grant the `repo` scope.

---

## Workflow

### Step 1 — Mine OSS repos locally
```bash
python scripts/mine_repos.py
```

This clones each repo in the `REPOS` list at the top of the script, extracts all merged PRs using local git commands, and auto-labels them. Edit the list to add or remove repos before running.

Produces:
- `data/clones/`                  ← cloned repos (reused on re-runs)
- `data/raw/pull_requests.csv`    ← one row per PR, auto-labeled
- `data/raw/commits.csv`          ← one row per commit, linked by pr_number

No manual labeling needed.

### Step 2 — Fill in your AI usage log (optional)
If any PRs in your dataset were written with AI assistance, log them in `data/ai_logs/ai_log.csv`:

```csv
pr_number,              ai_used, ai_tokens_in, ai_tokens_out, ai_agent_turns, human_edit_ratio
django/django#1234,     1,       3200,          5800,          12,             0.6
pallets/flask#567,      0,       0,             0,             0,              1.0
```

PRs not in this file default to no AI usage.

### Step 3 — Extract features
```bash
python scripts/extract_features.py
```

Joins PR data, commit aggregates, and AI log into a single feature table at `data/features.csv`.

### Step 4 — Train the model
```bash
python scripts/train.py
```

Trains a Random Forest on labeled PRs, prints evaluation metrics and feature importance, and saves the model to `model/`.

### Step 5 — Score a PR from CLI
```bash
python scripts/predict.py 42
```

### Step 6 — Or run the REST API
```bash
uvicorn scripts.predict:app --reload
```

Interactive docs at: http://localhost:8000/docs

---

## How Auto-Labeling Works

A PR is labeled **buggy (1)** if within 90 days of its merge either of these is true:
- A later commit reverts it directly (subject contains "Revert" and the PR number)
- A later bug-fix PR (subject contains fix/bug/patch/hotfix) touches the same files

Everything else is labeled **clean (0)**.

This is the same SZZ-based approach used in Just-In-Time defect prediction research (Kamei et al. 2013).

---

## Adding More Repos

Edit the `REPOS` list at the top of `mine_repos.py`:

```python
REPOS = [
    ("django",        "django"),
    ("pallets",       "flask"),
    ("apache",        "airflow"),
    ("psf",           "requests"),
    ("scikit-learn",  "scikit-learn"),
]
```

Five repos with 500 PRs each gives ~2,500 labeled examples. More is better — aim for 10+ repos if you want a robust model.

---

## API Usage

```
POST http://localhost:8000/score
Content-Type: application/json

{
  "pr_number": 42,
  "ai_used": 1,
  "ai_tokens_in": 3200,
  "ai_tokens_out": 5800,
  "ai_agent_turns": 12,
  "human_edit_ratio": 0.6
}
```

AI usage fields are optional — omit them if the PR was written without AI assistance.

### Response
```json
{
  "pr_number":  42,
  "title":      "Add payment retry logic",
  "author":     "janedev",
  "risk_pct":   73.4,
  "risk_label": "high",
  "top_contributors": {
    "has_late_night_commit": { "value": 1,   "importance": 0.142 },
    "time_in_review_hours":  { "value": 0.4, "importance": 0.118 },
    "human_edit_ratio":      { "value": 0.2, "importance": 0.097 }
  },
  "features": { ... }
}
```

### Risk levels
| Score    | Label     |
|----------|-----------|
| 0–30%    | 🟢 low    |
| 30–60%   | 🟡 medium |
| 60–100%  | 🔴 high   |

---

## Project Structure

```
pr-scorer/
├── data/
│   ├── clones/                       ← git clones (created by mine_repos.py)
│   ├── raw/
│   │   ├── pull_requests.csv         ← mined + auto-labeled PRs
│   │   └── commits.csv               ← commit-level data linked by pr_number
│   ├── ai_logs/
│   │   └── ai_log.csv                ← your manual AI usage log
│   └── features.csv                  ← combined feature table
├── model/
│   ├── pr_scorer.pkl                 ← trained model
│   └── feature_columns.pkl           ← feature column names
├── scripts/
│   ├── mine_repos.py                 ← Step 1: clone + extract + auto-label
│   ├── extract_features.py           ← Step 2: build feature table
│   ├── train.py                      ← Step 3: train and evaluate
│   └── predict.py                    ← Step 4: CLI + REST API
├── .env.example
├── requirements.txt
└── README.md
```