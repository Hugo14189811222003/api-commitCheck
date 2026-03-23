-- Crear la base de datos
CREATE DATABASE commitcheck_db;

-- Crear la tabla de usuarios
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    github_username VARCHAR(50) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE subscriptions (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          INTEGER       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_id          UUID          NOT NULL REFERENCES plans(id),
  status           VARCHAR(20)   NOT NULL DEFAULT 'active'
                     CHECK (status IN ('active', 'cancelled', 'past_due', 'trialing')),
  started_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  ends_at          TIMESTAMPTZ,
  cancelled_at     TIMESTAMPTZ,
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE github_organizations (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  github_org_id    BIGINT        NOT NULL UNIQUE,
  login            VARCHAR(255)  NOT NULL UNIQUE,
  name             VARCHAR(255),
  avatar_url       VARCHAR(1024),
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE api_keys (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key_hash         VARCHAR(255)  NOT NULL UNIQUE, -- Store hashed keys!
  name             VARCHAR(255)  NOT NULL,
  user_id          INTEGER       REFERENCES users(id) ON DELETE CASCADE,
  organization_id  UUID          REFERENCES github_organizations(id) ON DELETE CASCADE,
  
  -- Key should belong to either a user or an organization
  CHECK (
    (user_id IS NOT NULL AND organization_id IS NULL) OR 
    (organization_id IS NOT NULL AND user_id IS NULL)
  ),
  
  expires_at       TIMESTAMPTZ,
  last_used_at     TIMESTAMPTZ,
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
 
 CREATE TABLE repositories (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          INTEGER       REFERENCES users(id) ON DELETE CASCADE,
  organization_id  UUID          REFERENCES github_organizations(id) ON DELETE CASCADE,
  -- A repository should belong to either a user or an organization (or potentially both, depending on the system logic, but usually one owner at a time is tracked here)
  github_repo_id   BIGINT        NOT NULL,
  owner            VARCHAR(255)  NOT NULL,
  name             VARCHAR(255)  NOT NULL,
  full_name        VARCHAR(512)  NOT NULL UNIQUE,   -- e.g. "acme/my-app"
  default_branch   VARCHAR(100)  NOT NULL DEFAULT 'main',
  is_active        BOOLEAN       NOT NULL DEFAULT TRUE,
  risk_threshold   INT           NOT NULL DEFAULT 70
                     CHECK (risk_threshold BETWEEN 0 AND 100),
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
 

-- Table to store the platform's live commit analysis results
CREATE TABLE commit_analyses (
    id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    repository_id      UUID          NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    commit_hash        VARCHAR(40)   NOT NULL,
    
    risk_score         DECIMAL(5, 2) NOT NULL,
    risk_label         VARCHAR(20)   NOT NULL,
    confidence         DECIMAL(5, 2) NOT NULL,
    
    -- Extracted features during analysis
    lines_added        INTEGER       DEFAULT 0,
    lines_deleted      INTEGER       DEFAULT 0,
    files_modified     INTEGER       DEFAULT 0,
    
    -- Store structured data returned by the model server
    top_contributors   JSONB,
    commit_info        JSONB,
    
    analyzed_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    
    UNIQUE(repository_id, commit_hash)
);

-- Table to store the main Pull Request features and risk labels for training
CREATE TABLE dataset_pull_requests (
    id SERIAL PRIMARY KEY,
    repo VARCHAR(255) NOT NULL,
    pr_number VARCHAR(255) UNIQUE NOT NULL,
    merged_at TIMESTAMP,
    
    -- 1. Time Signals
    pr_merged_hour INTEGER,
    pr_merged_weekday INTEGER,
    is_friday_merge INTEGER,
    
    -- 2. Size Metrics
    lines_added INTEGER,
    lines_deleted INTEGER,
    changed_files INTEGER,
    total_churn INTEGER,
    churn_ratio DECIMAL(5, 3),
    
    -- 3. Commit Signals
    commit_count INTEGER,
    unique_authors INTEGER,
    has_late_night_commit INTEGER,
    earliest_commit_hour INTEGER,
    latest_commit_hour INTEGER,
    commit_hour_std DECIMAL(5, 2),
    
    -- 4. Code Diffusion
    subsystems_changed INTEGER,
    
    -- 5. Review & Approval Signals (Fetched from GitHub API)
    reviewer_count INTEGER,
    approvals_count INTEGER,
    pr_iteration_count INTEGER,
    
    -- 6. Context
    is_hotfix INTEGER,

    -- 7. AI Usage Signals (for the model server payload)
    ai_used INTEGER DEFAULT 0,
    ai_tokens_in INTEGER DEFAULT 0,
    ai_tokens_out INTEGER DEFAULT 0,
    ai_agent_turns INTEGER DEFAULT 0,
    human_edit_ratio DECIMAL(5, 3) DEFAULT 1.0,

    -- 8. Target Variable (Model Label)
    label INTEGER
);

-- Table to store individual commits that make up those PRs
CREATE TABLE dataset_commits (
    id SERIAL PRIMARY KEY,
    repo VARCHAR(255) NOT NULL,
    pr_number VARCHAR(255) NOT NULL,
    
    commit_hash VARCHAR(40) NOT NULL,
    author_email VARCHAR(255),
    committed_at TIMESTAMP,
    message TEXT,
    
    -- Additional granular features
    commit_hour INTEGER,
    is_late_night INTEGER,
    lines_added INTEGER,
    lines_deleted INTEGER,
    
    -- Establish relationship
    CONSTRAINT fk_dataset_pull_request 
        FOREIGN KEY (pr_number) 
        REFERENCES dataset_pull_requests(pr_number)
        ON DELETE CASCADE
);

CREATE TABLE plans (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name                plan_name        NOT NULL UNIQUE,
  display_name        VARCHAR(50)      NOT NULL,
  price_monthly_usd   NUMERIC(8,2)     NOT NULL DEFAULT 0,
  max_repos           INT              NOT NULL DEFAULT 1,   -- -1 = unlimited
  max_members         INT              NOT NULL DEFAULT 1,
  ai_review_trigger   BOOLEAN          NOT NULL DEFAULT FALSE,
  custom_model        BOOLEAN          NOT NULL DEFAULT FALSE,
  dashboard_access    BOOLEAN          NOT NULL DEFAULT FALSE,
  slack_integration   BOOLEAN          NOT NULL DEFAULT FALSE,
  parent_plan_id      UUID REFERENCES plans(id),             -- for recursive CTE
  created_at          TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);




CREATE INDEX idx_dataset_pr_repo ON dataset_pull_requests(repo);
CREATE INDEX idx_dataset_commits_pr_number ON dataset_commits(pr_number);