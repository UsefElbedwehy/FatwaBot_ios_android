-- Vector search: halve the index so it stays in cache.
--
-- Symptom: `POST /v1/search` was failing with a Postgres statement timeout
-- (`57014`), and when it did answer it took 15-75s for the same question, one
-- request to the next.
--
-- Cause, measured rather than guessed: the HNSW index over `chunks.embedding`
-- was 195 MB against `shared_buffers` of 224 MB, on a table totalling 733 MB.
-- It could not stay resident. Cold, an index scan read from disk and took
-- 12.3s; warm, the same call took 2.3ms. Cold crossed the timeout, so requests
-- were killed before the scan finished — and because they were killed, the
-- index never warmed. `pg_stat_all_indexes` recorded `idx_scan = 0` for its
-- entire life, while the FTS and trigram indexes on the same table were being
-- used normally.
--
-- (For the record: the zero scan count first looked like the planner refusing
-- the index, and the 583ms-inline vs 12.3s-through-the-function gap looked like
-- the `language sql` wrapper blocking inlining. Both readings were wrong. The
-- unchanged function runs in 2.3ms once the pages are cached; the earlier
-- numbers were measuring disk, not planning.)
--
-- Fix: index `embedding::halfvec(1024)` instead. pgvector's 2-byte float halves
-- the vector payload and shrinks the graph with it — 195 MB -> 65 MB here, a 3x
-- reduction that fits comfortably in cache with room for the heap. Recall loss
-- at 1024 dimensions is negligible: half-precision keeps ~3 decimal digits,
-- against cosine distances that differ between neighbours in the second.
--
-- The column stays `vector(1024)`. This is an expression index, so no data is
-- rewritten and nothing outside this file changes shape — only the ORDER BY has
-- to name the same expression for the index to be used.
--
-- This buys headroom, it does not create it indefinitely: the corpus is 24,977
-- chunks and batches 8-10 would roughly double that. At ~130 MB the halved
-- index is back to competing with the heap, so the instance will need more RAM
-- before the corpus grows much further.

create index if not exists chunks_embedding_hnsw_half_idx
    on fatwa.chunks using hnsw ((embedding::halfvec(1024)) halfvec_cosine_ops);

-- Must match the index expression exactly, or the planner silently falls back
-- to a full scan — which is the failure this migration exists to end.
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
        1 - ((c.embedding::halfvec(1024)) <=> (p_query_embedding::halfvec(1024))) as score
    from fatwa.chunks c
    join fatwa.documents d on d.id = c.document_id
    join fatwa.sources s on s.id = d.source_id
    join fatwa.scholars sc on sc.id = s.scholar_id
    where c.app_id = p_app_id
      and c.embedding is not null
      and s.license_status = 'granted' and s.active
      and sc.active
    order by (c.embedding::halfvec(1024)) <=> (p_query_embedding::halfvec(1024))
    limit p_match_count;
$$;

-- Dropped, not kept as a fallback: leaving 195 MB of unused index in place would
-- go on evicting the pages this change exists to keep resident, which is the
-- whole problem. Reverting means recreating it and restoring the previous
-- function body from 0042_fatwa_schema.sql.
drop index if exists fatwa.chunks_embedding_hnsw_idx;
