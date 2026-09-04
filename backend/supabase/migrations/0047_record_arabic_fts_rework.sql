-- Record the Arabic-FTS rework that was applied to production on 2026-09-04
-- without a migration. This file changes nothing; it writes down what is
-- already there so the repo can rebuild it.
--
-- Found by diffing `pg_proc`/`pg_indexes` against these files while planning
-- M5.1. Left undocumented, the next migration that touched search would have
-- silently reverted it — which is exactly what a first draft of 0048 did before
-- this check caught it.
--
-- What was changed, and why it was right:
--
--   1. `fatwa.normalize_ar(text)` — strips tashkeel, superscript alef, Quranic
--      marks and tatweel, and unifies أإآٱ→ا, ة→ه, ى→ي. Arabic text is written
--      with optional diacritics, so a user typing «صلاة الجماعة» would miss a
--      chunk spelling it «صَلاةُ الجَماعَة». `simple`-config `to_tsvector` does
--      no such folding on its own.
--
--   2. The `tsv` generated column and `chunks_tsv_idx` were dropped and
--      replaced by `chunks_tsv_norm_idx`, a GIN index over the *normalised*
--      tsvector. The generated column indexed raw text, so it could not serve
--      the normalised query. The expression index must match `search_fts`'s
--      expression exactly or the planner falls back to recomputing
--      `normalize_ar` per row across every chunk.
--
--   3. `chunks_text_trgm_idx` (70 MB) was dropped and `search_trigram` retired
--      to an empty result. Whole-chunk trigram similarity had to scan every
--      chunk — 30-60s — and returned nothing useful, since similarity between a
--      short question and a multi-paragraph chunk is meaningless. The function
--      is kept as a stub so an older deployment calling the RPC still works;
--      0048 removes the caller.
--
-- Written with IF NOT EXISTS / OR REPLACE so applying it to the live database
-- is a no-op, and applying it to a fresh one reproduces production.

create or replace function fatwa.normalize_ar(t text)
returns text
language sql
immutable
parallel safe
strict
as $$
  -- strip tashkeel/harakat, superscript alef, Quranic marks, tatweel; unify alef forms; ة->ه; ى->ي
  select translate(
    regexp_replace(t, '[ؐ-ًؚ-ٰٟۖ-ۭـ]', '', 'g'),
    'أإآٱةى', 'ااااهي');
$$;

alter table fatwa.chunks drop column if exists tsv;
drop index if exists fatwa.chunks_tsv_idx;
drop index if exists fatwa.chunks_text_trgm_idx;

create index if not exists chunks_tsv_norm_idx
    on fatwa.chunks using gin (to_tsvector('simple', fatwa.normalize_ar(text)));

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
    with q as (select plainto_tsquery('simple', fatwa.normalize_ar(p_query)) tsq)
    select
        c.id, c.document_id, s.id, s.scholar_id, c.text, c.page_number, c.video_timestamp,
        s.title, s.category, sc.name_translations,
        ts_rank_cd(to_tsvector('simple', fatwa.normalize_ar(c.text)), q.tsq) as score
    from q, fatwa.chunks c
    join fatwa.documents d on d.id = c.document_id
    join fatwa.sources s on s.id = d.source_id
    join fatwa.scholars sc on sc.id = s.scholar_id
    where c.app_id = p_app_id
      and to_tsvector('simple', fatwa.normalize_ar(c.text)) @@ q.tsq
      and s.license_status = 'granted' and s.active
      and sc.active
    order by score desc
    limit p_match_count;
$$;

create or replace function fatwa.search_trigram(
    p_app_id uuid,
    p_query text,
    p_match_count integer,
    p_min_similarity double precision
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
    -- Retired 2026-09-04: whole-chunk similarity scanned all chunks (30-60s)
    -- and returned nothing useful. Empty result so existing callers keep
    -- working; the caller is removed in 0048.
    select null::uuid, null::uuid, null::uuid, null::uuid, null::text, null::int,
           null::int, null::text, null::text, null::jsonb, null::float8
    where false;
$$;
