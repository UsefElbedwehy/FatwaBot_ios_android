-- 0042: fatwa schema (M5.0 — docs/features/ai-search-m5.0-spec.md).
-- scholars/sources/documents/chunks/answers_log for the AI fatwa-search
-- pipeline: OCR'd books chunked + embedded, retrieved hybrid (vector + FTS +
-- trigram), answered with citations verified against chunk text in code.
--
-- `fatwa.sources.license_status` defaults every ingested source to 'pending';
-- retrieval only ever reads 'granted' rows (enforced below in the search
-- functions, not just the app layer) — the whole pipeline is safe to build,
-- ingest, and pilot before any copyright decision is made.

create extension if not exists vector;
create extension if not exists pg_trgm;

create schema if not exists fatwa;

create table fatwa.scholars (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    name_translations jsonb not null default '{}'::jsonb,
    site_url text,
    youtube_url text,
    active boolean not null default true,
    created_at timestamptz not null default now()
);

create table fatwa.sources (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    scholar_id uuid not null references fatwa.scholars(id) on delete cascade,
    kind text not null check (kind in ('web', 'video', 'book')),
    -- web/video sources have a url; book sources have no url and instead keep
    -- the original filename/path for re-ingestion + audit.
    url text,
    origin_path text,
    title text not null,
    -- عقيدة/فقه/حديث/تفسير/فتاوى ولقاءات/... — powers فتوى-mode retrieval
    -- weighting (§Modes) and an admin filter. Null for sources not yet categorized.
    category text,
    total_pages integer,
    published_at timestamptz,
    -- retrieval only ever reads 'granted' — see fatwa.search_* functions below.
    license_status text not null default 'pending' check (license_status in ('granted', 'pending', 'unknown')),
    active boolean not null default true,
    ingested_at timestamptz,
    created_at timestamptz not null default now()
);

create index sources_scholar_idx on fatwa.sources (app_id, scholar_id);
create index sources_license_active_idx on fatwa.sources (app_id, license_status, active);

-- One row per book/video — keeps this table small; page/timestamp granularity
-- lives in fatwa.chunks. original_text for a book is the full OCR'd Markdown,
-- with an inline `<!-- page:N -->` marker before each page's content.
create table fatwa.documents (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    source_id uuid not null unique references fatwa.sources(id) on delete cascade,
    original_text text not null,
    -- future video sources: caption-track transcript (§YouTube captions).
    transcript text,
    lang text not null default 'ar',
    created_at timestamptz not null default now()
);

create table fatwa.chunks (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    document_id uuid not null references fatwa.documents(id) on delete cascade,
    text text not null,
    start_offset integer not null,
    end_offset integer not null,
    -- exactly one of page_number/video_timestamp is set per chunk (book vs. video source).
    page_number integer,
    video_timestamp integer,
    -- voyage-4 is 1024-dim (§Decisions locked in); null until the embed step runs.
    embedding vector(1024),
    -- 'simple' config: no Arabic stemming dictionary ships with Postgres, so
    -- this is tokenize+lowercase only — exact/near-exact term matching, which
    -- is FTS's role in the hybrid mix (vector catches paraphrase, trigram
    -- catches misremembered wording).
    tsv tsvector generated always as (to_tsvector('simple', text)) stored,
    created_at timestamptz not null default now(),
    constraint chunks_exactly_one_locator check ((page_number is not null) <> (video_timestamp is not null))
);

create index chunks_document_idx on fatwa.chunks (app_id, document_id);
create index chunks_tsv_idx on fatwa.chunks using gin (tsv);
create index chunks_text_trgm_idx on fatwa.chunks using gin (text gin_trgm_ops);
-- HNSW over ivfflat: no "train on existing rows" step needed, so it stays
-- correct through the incremental per-book ingestion this corpus needs.
create index chunks_embedding_hnsw_idx on fatwa.chunks using hnsw (embedding vector_cosine_ops);

create table fatwa.answers_log (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    user_id uuid not null references identity.users(id) on delete cascade,
    mode text not null check (mode in ('fatwa', 'hadith', 'general')),
    question text not null,
    retrieved_chunk_ids jsonb not null default '[]'::jsonb,
    citations jsonb not null default '[]'::jsonb,
    answer text not null default '',
    refused boolean not null default false,
    model text not null,
    created_at timestamptz not null default now()
);

create index answers_log_user_idx on fatwa.answers_log (app_id, user_id, created_at desc);

alter table fatwa.scholars enable row level security;
alter table fatwa.sources enable row level security;
alter table fatwa.documents enable row level security;
alter table fatwa.chunks enable row level security;
alter table fatwa.answers_log enable row level security;
-- deny-by-default, as every other domain schema: no policies; only service_role
-- (BYPASSRLS) reaches these tables, via the search functions below or direct CRUD.

-- Hybrid-search building blocks (§Retrieval). PostgREST can't express vector
-- cosine ordering or ts_rank/similarity scoring through its query-string
-- filter API, so these are called via supabase-js `.rpc(...)` from
-- SupabaseFatwaSearchRepo. Each returns the same row shape so retrieval.ts
-- can merge them with Reciprocal Rank Fusion without caring which one a row
-- came from. All three enforce license_status='granted' + active in SQL —
-- not just the app layer (§Non-negotiable).
create or replace function fatwa.search_vector(
    p_app_id uuid,
    p_query_embedding vector(1024),
    p_match_count integer
)
returns table (
    chunk_id uuid,
    document_id uuid,
    source_id uuid,
    scholar_id uuid,
    chunk_text text,
    page_number integer,
    video_timestamp integer,
    source_title text,
    source_category text,
    scholar_name jsonb,
    score double precision
)
language sql
stable
as $$
    select
        c.id, c.document_id, s.id, s.scholar_id, c.text, c.page_number, c.video_timestamp,
        s.title, s.category, sc.name_translations,
        1 - (c.embedding <=> p_query_embedding) as score
    from fatwa.chunks c
    join fatwa.documents d on d.id = c.document_id
    join fatwa.sources s on s.id = d.source_id
    join fatwa.scholars sc on sc.id = s.scholar_id
    where c.app_id = p_app_id
      and c.embedding is not null
      and s.license_status = 'granted' and s.active
      and sc.active
    order by c.embedding <=> p_query_embedding
    limit p_match_count;
$$;

create or replace function fatwa.search_fts(
    p_app_id uuid,
    p_query text,
    p_match_count integer
)
returns table (
    chunk_id uuid,
    document_id uuid,
    source_id uuid,
    scholar_id uuid,
    chunk_text text,
    page_number integer,
    video_timestamp integer,
    source_title text,
    source_category text,
    scholar_name jsonb,
    score double precision
)
language sql
stable
as $$
    select
        c.id, c.document_id, s.id, s.scholar_id, c.text, c.page_number, c.video_timestamp,
        s.title, s.category, sc.name_translations,
        ts_rank_cd(c.tsv, plainto_tsquery('simple', p_query)) as score
    from fatwa.chunks c
    join fatwa.documents d on d.id = c.document_id
    join fatwa.sources s on s.id = d.source_id
    join fatwa.scholars sc on sc.id = s.scholar_id
    where c.app_id = p_app_id
      and c.tsv @@ plainto_tsquery('simple', p_query)
      and s.license_status = 'granted' and s.active
      and sc.active
    order by score desc
    limit p_match_count;
$$;

-- Mode 2 (استخراج الأحاديث): matches *approximate/misremembered* wording —
-- a user paraphrasing a hadith rarely matches FTS's exact tokens.
create or replace function fatwa.search_trigram(
    p_app_id uuid,
    p_query text,
    p_match_count integer,
    p_min_similarity double precision default 0.15
)
returns table (
    chunk_id uuid,
    document_id uuid,
    source_id uuid,
    scholar_id uuid,
    chunk_text text,
    page_number integer,
    video_timestamp integer,
    source_title text,
    source_category text,
    scholar_name jsonb,
    score double precision
)
language sql
stable
as $$
    select
        c.id, c.document_id, s.id, s.scholar_id, c.text, c.page_number, c.video_timestamp,
        s.title, s.category, sc.name_translations,
        similarity(c.text, p_query) as score
    from fatwa.chunks c
    join fatwa.documents d on d.id = c.document_id
    join fatwa.sources s on s.id = d.source_id
    join fatwa.scholars sc on sc.id = s.scholar_id
    where c.app_id = p_app_id
      and similarity(c.text, p_query) >= p_min_similarity
      and s.license_status = 'granted' and s.active
      and sc.active
    order by score desc
    limit p_match_count;
$$;

-- Expose `fatwa` to PostgREST + grant service_role, same mechanism as
-- migration 0011 (which covers the schemas that existed at that point).
do $$
begin
    grant usage on schema fatwa to anon, authenticated, service_role;
    grant all privileges on all tables in schema fatwa to service_role;
    grant all privileges on all sequences in schema fatwa to service_role;
    grant all privileges on all routines in schema fatwa to service_role;
    alter default privileges in schema fatwa grant all on tables to service_role;
    alter default privileges in schema fatwa grant all on sequences to service_role;
end $$;

-- `alter role ... set` overwrites rather than appends, so this restates the
-- full exposed-schema list from 0011 plus 'fatwa'.
alter role authenticator
    set pgrst.db_schemas = 'public, graphql_public, config, identity, content, admin, gamification, search, notifications, fatwa';

notify pgrst, 'reload config';
