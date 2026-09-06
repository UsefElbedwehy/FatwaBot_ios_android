-- Three retrieval-quality changes from the 2026-09-06 search review
-- (docs/features/search-quality-m5.2.md):
--
--   1. answers_log records WHY a refusal happened and which citations were
--      dropped. 31 of the first 59 searches refused and every one of them had
--      retrieved 8 chunks, so retrieval was never the cause — but the log kept
--      only the citations that survived verification, so "the model refused
--      itself" and "the verifier dropped every citation" were the same row.
--   2. search_vector / search_fts report whether a chunk is OCR-shattered, so
--      retrieval can rank a readable chunk above a wrecked one. The corpus
--      audit (docs/features/corpus-ocr-audit.md) found 85% of chunks carry the
--      signature below; computing it on the 30 rows a search returns costs
--      microseconds, where a stored column would have meant rewriting a table
--      that carries a 65 MB HNSW index.
--   3. content.search_hadith: hadith mode searches the 36,183 hadiths already
--      imported into content.hadith_entries (20,972 graded) instead of the
--      fatwa corpus, which is not a hadith collection and refused 7 of 9
--      takhrij questions.

alter table fatwa.answers_log
    add column if not exists refusal_reason text,
    add column if not exists dropped_citations jsonb not null default '[]'::jsonb;

comment on column fatwa.answers_log.refusal_reason is
    'null when answered; model_refused | all_citations_dropped | no_chunks';

-- Same DROP-then-CREATE as 0048: adding an OUT column changes the row type.
drop function if exists fatwa.search_vector(uuid, vector, integer);

create function fatwa.search_vector(
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
    source_kind text,
    source_url text,
    scholar_name jsonb,
    score double precision,
    ocr_shattered boolean
)
language sql
stable
as $$
    select
        c.id, c.document_id, s.id, s.scholar_id, c.text, c.page_number, c.video_timestamp,
        s.title, s.category, s.kind, s.url, sc.name_translations,
        1 - ((c.embedding::halfvec(1024)) <=> (p_query_embedding::halfvec(1024))) as score,
        -- Three or more consecutive isolated Arabic letters: a line the OCR
        -- shattered rather than read. Validated against the corpus by hand in
        -- the audit; near-zero false positives in prose.
        c.text ~ '(^|[[:space:]])[ء-ي][[:space:]]+[ء-ي][[:space:]]+[ء-ي]([[:space:]]|$)' as ocr_shattered
    from fatwa.chunks c
    join fatwa.documents d on d.id = c.document_id
    join fatwa.sources s on s.id = d.source_id
    join fatwa.scholars sc on sc.id = s.scholar_id
    where c.app_id = p_app_id
      and c.embedding is not null
      and s.license_status = 'granted' and s.active
      and sc.active
    -- Must keep naming the expression the halfvec index is built on (0043), or
    -- the planner falls back to a full scan and the statement times out.
    order by (c.embedding::halfvec(1024)) <=> (p_query_embedding::halfvec(1024))
    limit p_match_count;
$$;

drop function if exists fatwa.search_fts(uuid, text, integer);

create function fatwa.search_fts(
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
    source_kind text,
    source_url text,
    scholar_name jsonb,
    score double precision,
    ocr_shattered boolean
)
language sql
stable
as $$
    with q as (select plainto_tsquery('simple', fatwa.normalize_ar(p_query)) tsq)
    select
        c.id, c.document_id, s.id, s.scholar_id, c.text, c.page_number, c.video_timestamp,
        s.title, s.category, s.kind, s.url, sc.name_translations,
        ts_rank_cd(to_tsvector('simple', fatwa.normalize_ar(c.text)), q.tsq) as score,
        c.text ~ '(^|[[:space:]])[ء-ي][[:space:]]+[ء-ي][[:space:]]+[ء-ي]([[:space:]]|$)' as ocr_shattered
    from q, fatwa.chunks c
    join fatwa.documents d on d.id = c.document_id
    join fatwa.sources s on s.id = d.source_id
    join fatwa.scholars sc on sc.id = s.scholar_id
    where c.app_id = p_app_id
      -- Same expression as chunks_tsv_norm_idx (0047); changing one without the
      -- other turns this into a per-row recompute over every chunk.
      and to_tsvector('simple', fatwa.normalize_ar(c.text)) @@ q.tsq
      and s.license_status = 'granted' and s.active
      and sc.active
    order by score desc
    limit p_match_count;
$$;

-- Hadith mode. The same normalised FTS as the fatwa corpus, over the matn.
-- `fatwa.normalize_ar` is immutable (0047), which is what lets it sit inside
-- an index expression.
create index if not exists hadith_entries_tsv_norm_idx
    on content.hadith_entries using gin (to_tsvector('simple', fatwa.normalize_ar(arabic_text)));

-- Returns the same row shape as the fatwa search functions so the edge
-- function's retrieval, citation verification and answer prompt need no
-- second code path:
--   chunk_text   = the matn, then the grading and the collection reference on
--                  their own lines — all of it quotable, so a citation of the
--                  grading verifies exactly like a citation of the wording.
--   page_number  = the hadith's number within its collection (the locator).
--   scholar_name = the collection's name; there is no single scholar behind
--                  a canonical collection, and the client groups cards by it.
--   ocr_shattered = false: this text was typed, not scanned.
create or replace function content.search_hadith(
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
    source_kind text,
    source_url text,
    scholar_name jsonb,
    score double precision,
    ocr_shattered boolean
)
language sql
stable
as $$
    with q as (select plainto_tsquery('simple', fatwa.normalize_ar(p_query)) tsq)
    select
        h.id, h.collection_id, h.collection_id, h.collection_id,
        h.arabic_text
          || E'\n\nالدرجة: ' || coalesce(nullif(h.grading, ''), 'غير مذكورة')
          || E'\nالمصدر: ' || coalesce(c.name_translations->>'ar', c.slug) || ' (رقم ' || h.number || ')',
        h.number,
        null::integer,
        coalesce(c.name_translations->>'ar', c.slug),
        'hadith',
        'book',
        null::text,
        c.name_translations,
        ts_rank_cd(to_tsvector('simple', fatwa.normalize_ar(h.arabic_text)), q.tsq) as score,
        false
    from q, content.hadith_entries h
    join content.hadith_collections c on c.id = h.collection_id
    where h.app_id = p_app_id
      and h.published
      and to_tsvector('simple', fatwa.normalize_ar(h.arabic_text)) @@ q.tsq
    order by score desc
    limit p_match_count;
$$;
