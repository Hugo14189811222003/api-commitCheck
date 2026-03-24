--
-- PostgreSQL database dump
--

\restrict 3jeXCgFgdQLXtlhshcUpIKBFYtAM2yhUsU6PcWkbwb2VnOUQyedZfLlFyHLzj8n

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

-- Started on 2026-03-23 23:30:54

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 7 (class 2615 OID 173127)
-- Name: dataset; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA dataset;


ALTER SCHEMA dataset OWNER TO postgres;

--
-- TOC entry 2 (class 3079 OID 172915)
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- TOC entry 5156 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- TOC entry 875 (class 1247 OID 172927)
-- Name: plan_name; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.plan_name AS ENUM (
    'free',
    'starter',
    'pro',
    'enterprise'
);


ALTER TYPE public.plan_name OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 232 (class 1259 OID 173148)
-- Name: commits; Type: TABLE; Schema: dataset; Owner: postgres
--

CREATE TABLE dataset.commits (
    id integer NOT NULL,
    repo character varying(255) NOT NULL,
    pr_number character varying(255) NOT NULL,
    commit_hash character varying(40) NOT NULL,
    author_email character varying(255),
    committed_at timestamp without time zone,
    message text,
    commit_hour integer,
    is_late_night integer,
    lines_added integer,
    lines_deleted integer
);


ALTER TABLE dataset.commits OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 173147)
-- Name: commits_id_seq; Type: SEQUENCE; Schema: dataset; Owner: postgres
--

CREATE SEQUENCE dataset.commits_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dataset.commits_id_seq OWNER TO postgres;

--
-- TOC entry 5157 (class 0 OID 0)
-- Dependencies: 231
-- Name: commits_id_seq; Type: SEQUENCE OWNED BY; Schema: dataset; Owner: postgres
--

ALTER SEQUENCE dataset.commits_id_seq OWNED BY dataset.commits.id;


--
-- TOC entry 230 (class 1259 OID 173129)
-- Name: pull_requests; Type: TABLE; Schema: dataset; Owner: postgres
--

CREATE TABLE dataset.pull_requests (
    id integer NOT NULL,
    repo character varying(255) NOT NULL,
    pr_number character varying(255) NOT NULL,
    merged_at timestamp without time zone,
    pr_merged_hour integer,
    pr_merged_weekday integer,
    is_friday_merge integer,
    lines_added integer,
    lines_deleted integer,
    changed_files integer,
    total_churn integer,
    churn_ratio numeric(5,3),
    commit_count integer,
    unique_authors integer,
    has_late_night_commit integer,
    earliest_commit_hour integer,
    latest_commit_hour integer,
    commit_hour_std numeric(5,2),
    subsystems_changed integer,
    reviewer_count integer,
    approvals_count integer,
    pr_iteration_count integer,
    is_hotfix integer,
    ai_used integer DEFAULT 0,
    ai_tokens_in integer DEFAULT 0,
    ai_tokens_out integer DEFAULT 0,
    ai_agent_turns integer DEFAULT 0,
    human_edit_ratio numeric(5,3) DEFAULT 1.0,
    label integer
);


ALTER TABLE dataset.pull_requests OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 173128)
-- Name: pull_requests_id_seq; Type: SEQUENCE; Schema: dataset; Owner: postgres
--

CREATE SEQUENCE dataset.pull_requests_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dataset.pull_requests_id_seq OWNER TO postgres;

--
-- TOC entry 5158 (class 0 OID 0)
-- Dependencies: 229
-- Name: pull_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: dataset; Owner: postgres
--

ALTER SEQUENCE dataset.pull_requests_id_seq OWNED BY dataset.pull_requests.id;


--
-- TOC entry 227 (class 1259 OID 173068)
-- Name: api_keys; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.api_keys (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    key_hash character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    user_id integer,
    organization_id uuid,
    expires_at timestamp with time zone,
    last_used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT api_keys_check CHECK ((((user_id IS NOT NULL) AND (organization_id IS NULL)) OR ((organization_id IS NOT NULL) AND (user_id IS NULL))))
);


ALTER TABLE public.api_keys OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 173094)
-- Name: commit_analyses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.commit_analyses (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    repository_id uuid NOT NULL,
    commit_hash character varying(40) NOT NULL,
    risk_score numeric(5,2) NOT NULL,
    risk_label character varying(20) NOT NULL,
    confidence numeric(5,2) NOT NULL,
    lines_added integer DEFAULT 0,
    lines_deleted integer DEFAULT 0,
    files_modified integer DEFAULT 0,
    top_contributors jsonb,
    commit_info jsonb,
    analyzed_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.commit_analyses OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 173013)
-- Name: github_organizations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.github_organizations (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    github_org_id bigint NOT NULL,
    login character varying(255) NOT NULL,
    name character varying(255),
    avatar_url character varying(1024),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.github_organizations OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 172955)
-- Name: plans; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.plans (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name public.plan_name NOT NULL,
    display_name character varying(50) NOT NULL,
    price_monthly_usd numeric(8,2) DEFAULT 0 NOT NULL,
    max_repos integer DEFAULT 1 NOT NULL,
    max_members integer DEFAULT 1 NOT NULL,
    ai_review_trigger boolean DEFAULT false NOT NULL,
    custom_model boolean DEFAULT false NOT NULL,
    dashboard_access boolean DEFAULT false NOT NULL,
    slack_integration boolean DEFAULT false NOT NULL,
    parent_plan_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.plans OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 173032)
-- Name: repositories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.repositories (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id integer,
    organization_id uuid,
    github_repo_id bigint NOT NULL,
    name character varying(255) NOT NULL,
    full_name character varying(512) NOT NULL,
    default_branch character varying(100) DEFAULT 'main'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    risk_threshold integer DEFAULT 70 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT repositories_check CHECK ((((user_id IS NOT NULL) AND (organization_id IS NULL)) OR ((organization_id IS NOT NULL) AND (user_id IS NULL)))),
    CONSTRAINT repositories_risk_threshold_check CHECK (((risk_threshold >= 0) AND (risk_threshold <= 100)))
);


ALTER TABLE public.repositories OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 172987)
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.subscriptions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id integer NOT NULL,
    plan_id uuid NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    ends_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT subscriptions_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'cancelled'::character varying, 'past_due'::character varying, 'trialing'::character varying])::text[])))
);


ALTER TABLE public.subscriptions OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 172936)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    username character varying(50) NOT NULL,
    email character varying(100) NOT NULL,
    password character varying(255) NOT NULL,
    github_username character varying(50) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 172935)
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- TOC entry 5159 (class 0 OID 0)
-- Dependencies: 221
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- TOC entry 4942 (class 2604 OID 173151)
-- Name: commits id; Type: DEFAULT; Schema: dataset; Owner: postgres
--

ALTER TABLE ONLY dataset.commits ALTER COLUMN id SET DEFAULT nextval('dataset.commits_id_seq'::regclass);


--
-- TOC entry 4936 (class 2604 OID 173132)
-- Name: pull_requests id; Type: DEFAULT; Schema: dataset; Owner: postgres
--

ALTER TABLE ONLY dataset.pull_requests ALTER COLUMN id SET DEFAULT nextval('dataset.pull_requests_id_seq'::regclass);


--
-- TOC entry 4905 (class 2604 OID 172939)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- TOC entry 4992 (class 2606 OID 173159)
-- Name: commits commits_pkey; Type: CONSTRAINT; Schema: dataset; Owner: postgres
--

ALTER TABLE ONLY dataset.commits
    ADD CONSTRAINT commits_pkey PRIMARY KEY (id);


--
-- TOC entry 4988 (class 2606 OID 173144)
-- Name: pull_requests pull_requests_pkey; Type: CONSTRAINT; Schema: dataset; Owner: postgres
--

ALTER TABLE ONLY dataset.pull_requests
    ADD CONSTRAINT pull_requests_pkey PRIMARY KEY (id);


--
-- TOC entry 4990 (class 2606 OID 173146)
-- Name: pull_requests pull_requests_pr_number_key; Type: CONSTRAINT; Schema: dataset; Owner: postgres
--

ALTER TABLE ONLY dataset.pull_requests
    ADD CONSTRAINT pull_requests_pr_number_key UNIQUE (pr_number);


--
-- TOC entry 4975 (class 2606 OID 173083)
-- Name: api_keys api_keys_key_hash_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_key_hash_key UNIQUE (key_hash);


--
-- TOC entry 4977 (class 2606 OID 173081)
-- Name: api_keys api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_pkey PRIMARY KEY (id);


--
-- TOC entry 4981 (class 2606 OID 173112)
-- Name: commit_analyses commit_analyses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.commit_analyses
    ADD CONSTRAINT commit_analyses_pkey PRIMARY KEY (id);


--
-- TOC entry 4983 (class 2606 OID 173114)
-- Name: commit_analyses commit_analyses_repository_id_commit_hash_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.commit_analyses
    ADD CONSTRAINT commit_analyses_repository_id_commit_hash_key UNIQUE (repository_id, commit_hash);


--
-- TOC entry 4963 (class 2606 OID 173029)
-- Name: github_organizations github_organizations_github_org_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.github_organizations
    ADD CONSTRAINT github_organizations_github_org_id_key UNIQUE (github_org_id);


--
-- TOC entry 4965 (class 2606 OID 173031)
-- Name: github_organizations github_organizations_login_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.github_organizations
    ADD CONSTRAINT github_organizations_login_key UNIQUE (login);


--
-- TOC entry 4967 (class 2606 OID 173027)
-- Name: github_organizations github_organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.github_organizations
    ADD CONSTRAINT github_organizations_pkey PRIMARY KEY (id);


--
-- TOC entry 4956 (class 2606 OID 172981)
-- Name: plans plans_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plans
    ADD CONSTRAINT plans_name_key UNIQUE (name);


--
-- TOC entry 4958 (class 2606 OID 172979)
-- Name: plans plans_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plans
    ADD CONSTRAINT plans_pkey PRIMARY KEY (id);


--
-- TOC entry 4971 (class 2606 OID 173057)
-- Name: repositories repositories_full_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.repositories
    ADD CONSTRAINT repositories_full_name_key UNIQUE (full_name);


--
-- TOC entry 4973 (class 2606 OID 173055)
-- Name: repositories repositories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.repositories
    ADD CONSTRAINT repositories_pkey PRIMARY KEY (id);


--
-- TOC entry 4961 (class 2606 OID 173002)
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- TOC entry 4948 (class 2606 OID 172952)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- TOC entry 4950 (class 2606 OID 172954)
-- Name: users users_github_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_github_username_key UNIQUE (github_username);


--
-- TOC entry 4952 (class 2606 OID 172948)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 4954 (class 2606 OID 172950)
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- TOC entry 4993 (class 1259 OID 173167)
-- Name: idx_dataset_commits_hash; Type: INDEX; Schema: dataset; Owner: postgres
--

CREATE INDEX idx_dataset_commits_hash ON dataset.commits USING btree (commit_hash);


--
-- TOC entry 4994 (class 1259 OID 173166)
-- Name: idx_dataset_commits_pr; Type: INDEX; Schema: dataset; Owner: postgres
--

CREATE INDEX idx_dataset_commits_pr ON dataset.commits USING btree (pr_number);


--
-- TOC entry 4986 (class 1259 OID 173165)
-- Name: idx_dataset_pr_repo; Type: INDEX; Schema: dataset; Owner: postgres
--

CREATE INDEX idx_dataset_pr_repo ON dataset.pull_requests USING btree (repo);


--
-- TOC entry 4978 (class 1259 OID 173126)
-- Name: idx_api_keys_org_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_api_keys_org_id ON public.api_keys USING btree (organization_id);


--
-- TOC entry 4979 (class 1259 OID 173125)
-- Name: idx_api_keys_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_api_keys_user_id ON public.api_keys USING btree (user_id);


--
-- TOC entry 4984 (class 1259 OID 173124)
-- Name: idx_commit_analyses_hash; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_commit_analyses_hash ON public.commit_analyses USING btree (commit_hash);


--
-- TOC entry 4985 (class 1259 OID 173123)
-- Name: idx_commit_analyses_repo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_commit_analyses_repo ON public.commit_analyses USING btree (repository_id);


--
-- TOC entry 4968 (class 1259 OID 173122)
-- Name: idx_repositories_org_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_repositories_org_id ON public.repositories USING btree (organization_id);


--
-- TOC entry 4969 (class 1259 OID 173121)
-- Name: idx_repositories_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_repositories_user_id ON public.repositories USING btree (user_id);


--
-- TOC entry 4959 (class 1259 OID 173120)
-- Name: idx_subscriptions_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_subscriptions_user_id ON public.subscriptions USING btree (user_id);


--
-- TOC entry 5003 (class 2606 OID 173160)
-- Name: commits fk_dataset_pr; Type: FK CONSTRAINT; Schema: dataset; Owner: postgres
--

ALTER TABLE ONLY dataset.commits
    ADD CONSTRAINT fk_dataset_pr FOREIGN KEY (pr_number) REFERENCES dataset.pull_requests(pr_number) ON DELETE CASCADE;


--
-- TOC entry 5000 (class 2606 OID 173089)
-- Name: api_keys api_keys_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.github_organizations(id) ON DELETE CASCADE;


--
-- TOC entry 5001 (class 2606 OID 173084)
-- Name: api_keys api_keys_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5002 (class 2606 OID 173115)
-- Name: commit_analyses commit_analyses_repository_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.commit_analyses
    ADD CONSTRAINT commit_analyses_repository_id_fkey FOREIGN KEY (repository_id) REFERENCES public.repositories(id) ON DELETE CASCADE;


--
-- TOC entry 4995 (class 2606 OID 172982)
-- Name: plans plans_parent_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plans
    ADD CONSTRAINT plans_parent_plan_id_fkey FOREIGN KEY (parent_plan_id) REFERENCES public.plans(id);


--
-- TOC entry 4998 (class 2606 OID 173063)
-- Name: repositories repositories_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.repositories
    ADD CONSTRAINT repositories_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.github_organizations(id) ON DELETE CASCADE;


--
-- TOC entry 4999 (class 2606 OID 173058)
-- Name: repositories repositories_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.repositories
    ADD CONSTRAINT repositories_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4996 (class 2606 OID 173008)
-- Name: subscriptions subscriptions_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.plans(id);


--
-- TOC entry 4997 (class 2606 OID 173003)
-- Name: subscriptions subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


-- Completed on 2026-03-23 23:30:54

--
-- PostgreSQL database dump complete
--

\unrestrict 3jeXCgFgdQLXtlhshcUpIKBFYtAM2yhUsU6PcWkbwb2VnOUQyedZfLlFyHLzj8n

