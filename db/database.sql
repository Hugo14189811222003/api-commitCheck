-- =============================================================================
-- CommitCheck DB — Schema v2
-- Cambios respecto a v1:
--   1. Orden corregido (plans antes de subscriptions)
--   2. CREATE TYPE plan_name agregado
--   3. Campo owner removido de repositories (redundante con users/github_organizations)
--   4. Patrón de ownership extraído a comentario documentado
--   5. Dataset movido a schema separado (dataset.*)
--   6. Índices adicionales en commit_analyses y repositories
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------
CREATE TYPE plan_name AS ENUM ('free', 'starter', 'pro', 'enterprise');

-- =============================================================================
-- CORE SCHEMA
-- =============================================================================

CREATE TABLE users (
    id               SERIAL        PRIMARY KEY,
    username         VARCHAR(50)   NOT NULL UNIQUE,
    email            VARCHAR(100)  NOT NULL UNIQUE,
    password         VARCHAR(255)  NOT NULL,
    github_username  VARCHAR(50)   NOT NULL UNIQUE,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Plans must exist before subscriptions (forward ref fix)
CREATE TABLE plans (
    id                  UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                plan_name    NOT NULL UNIQUE,
    display_name        VARCHAR(50)  NOT NULL,
    price_monthly_usd   NUMERIC(8,2) NOT NULL DEFAULT 0,
    max_repos           INT          NOT NULL DEFAULT 1,   -- -1 = unlimited
    max_members         INT          NOT NULL DEFAULT 1,
    ai_review_trigger   BOOLEAN      NOT NULL DEFAULT FALSE,
    custom_model        BOOLEAN      NOT NULL DEFAULT FALSE,
    dashboard_access    BOOLEAN      NOT NULL DEFAULT FALSE,
    slack_integration   BOOLEAN      NOT NULL DEFAULT FALSE,
    parent_plan_id      UUID         REFERENCES plans(id), -- para CTEs recursivas
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE subscriptions (
    id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id       INTEGER     NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_id       UUID        NOT NULL REFERENCES plans(id),
    status        VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'cancelled', 'past_due', 'trialing')),
    started_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ends_at       TIMESTAMPTZ,
    cancelled_at  TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE github_organizations (
    id             UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    github_org_id  BIGINT        NOT NULL UNIQUE,
    login          VARCHAR(255)  NOT NULL UNIQUE,
    name           VARCHAR(255),
    avatar_url     VARCHAR(1024),
    created_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Nota de diseño — patrón de ownership exclusivo
-- Tanto repositories como api_keys pueden pertenecer a un usuario O a una
-- organización, nunca a ambos. El CHECK constraint lo garantiza.
-- ---------------------------------------------------------------------------

CREATE TABLE repositories (
    id               UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id          INTEGER      REFERENCES users(id) ON DELETE CASCADE,
    organization_id  UUID         REFERENCES github_organizations(id) ON DELETE CASCADE,
    CHECK (
        (user_id IS NOT NULL AND organization_id IS NULL) OR
        (organization_id IS NOT NULL AND user_id IS NULL)
    ),
    github_repo_id   BIGINT       NOT NULL,
    -- owner y name se derivan de users.github_username / github_organizations.login
    -- Se mantienen aquí como desnormalización controlada para lecturas rápidas
    name             VARCHAR(255) NOT NULL,
    full_name        VARCHAR(512) NOT NULL UNIQUE,  -- e.g. "acme/my-app"
    default_branch   VARCHAR(100) NOT NULL DEFAULT 'main',
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE,
    risk_threshold   INT          NOT NULL DEFAULT 70
                       CHECK (risk_threshold BETWEEN 0 AND 100),
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE api_keys (
    id               UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    key_hash         VARCHAR(255)  NOT NULL UNIQUE, -- nunca almacenar la key en claro
    name             VARCHAR(255)  NOT NULL,
    user_id          INTEGER       REFERENCES users(id) ON DELETE CASCADE,
    organization_id  UUID          REFERENCES github_organizations(id) ON DELETE CASCADE,
    CHECK (
        (user_id IS NOT NULL AND organization_id IS NULL) OR
        (organization_id IS NOT NULL AND user_id IS NULL)
    ),
    expires_at       TIMESTAMPTZ,
    last_used_at     TIMESTAMPTZ,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE commit_analyses (
    id               UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    repository_id    UUID          NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    commit_hash      VARCHAR(40)   NOT NULL,
    risk_score       DECIMAL(5,2)  NOT NULL,
    risk_label       VARCHAR(20)   NOT NULL,
    confidence       DECIMAL(5,2)  NOT NULL,
    lines_added      INTEGER       DEFAULT 0,
    lines_deleted    INTEGER       DEFAULT 0,
    files_modified   INTEGER       DEFAULT 0,
    top_contributors JSONB,
    commit_info      JSONB,
    analyzed_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    UNIQUE (repository_id, commit_hash)
);

-- =============================================================================
-- INDEXES — CORE
-- =============================================================================

CREATE INDEX idx_subscriptions_user_id   ON subscriptions(user_id);
CREATE INDEX idx_repositories_user_id    ON repositories(user_id);
CREATE INDEX idx_repositories_org_id     ON repositories(organization_id);
CREATE INDEX idx_commit_analyses_repo    ON commit_analyses(repository_id);
CREATE INDEX idx_commit_analyses_hash    ON commit_analyses(commit_hash);
CREATE INDEX idx_api_keys_user_id        ON api_keys(user_id);
CREATE INDEX idx_api_keys_org_id         ON api_keys(organization_id);

-- =============================================================================
-- DATASET SCHEMA (entrenamiento ML — separado del schema de producción)
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS dataset;

CREATE TABLE dataset.pull_requests (
    id          SERIAL       PRIMARY KEY,
    repo        VARCHAR(255) NOT NULL,
    pr_number   VARCHAR(255) NOT NULL UNIQUE,
    merged_at   TIMESTAMP,

    -- 1. Time signals
    pr_merged_hour     INTEGER,
    pr_merged_weekday  INTEGER,
    is_friday_merge    INTEGER,

    -- 2. Size metrics
    lines_added    INTEGER,
    lines_deleted  INTEGER,
    changed_files  INTEGER,
    total_churn    INTEGER,
    churn_ratio    DECIMAL(5,3),

    -- 3. Commit signals
    commit_count         INTEGER,
    unique_authors       INTEGER,
    has_late_night_commit INTEGER,
    earliest_commit_hour  INTEGER,
    latest_commit_hour    INTEGER,
    commit_hour_std       DECIMAL(5,2),

    -- 4. Code diffusion
    subsystems_changed INTEGER,

    -- 5. Review & approval signals
    reviewer_count      INTEGER,
    approvals_count     INTEGER,
    pr_iteration_count  INTEGER,

    -- 6. Context
    is_hotfix INTEGER,

    -- 7. AI usage signals
    ai_used          INTEGER       DEFAULT 0,
    ai_tokens_in     INTEGER       DEFAULT 0,
    ai_tokens_out    INTEGER       DEFAULT 0,
    ai_agent_turns   INTEGER       DEFAULT 0,
    human_edit_ratio DECIMAL(5,3)  DEFAULT 1.0,

    -- 8. Target variable
    label INTEGER
);

CREATE TABLE dataset.commits (
    id          SERIAL       PRIMARY KEY,
    repo        VARCHAR(255) NOT NULL,
    pr_number   VARCHAR(255) NOT NULL,
    commit_hash VARCHAR(40)  NOT NULL,
    author_email VARCHAR(255),
    committed_at TIMESTAMP,
    message      TEXT,
    commit_hour  INTEGER,
    is_late_night INTEGER,
    lines_added  INTEGER,
    lines_deleted INTEGER,

    CONSTRAINT fk_dataset_pr
        FOREIGN KEY (pr_number)
        REFERENCES dataset.pull_requests(pr_number)
        ON DELETE CASCADE
);

-- =============================================================================
-- INDEXES — DATASET
-- =============================================================================

CREATE INDEX idx_dataset_pr_repo      ON dataset.pull_requests(repo);
CREATE INDEX idx_dataset_commits_pr   ON dataset.commits(pr_number);
CREATE INDEX idx_dataset_commits_hash ON dataset.commits(commit_hash);