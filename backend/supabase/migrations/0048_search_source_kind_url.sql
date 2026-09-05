-- Return each hit's source kind and url, so the client can say honestly whether
-- an answer is also available as a video or on the web.
--
-- The M5.1 result design shows an availability badge per scholar card ("متاح على
-- يوتيوب" and so on). That has to be derived from the *verified citations*, not
-- asked of the answer model — a model asked "is this on YouTube?" will happily
-- say yes. `fatwa.sources` has recorded `kind` and `url` since 0042; the search
-- functions simply weren't returning them.
--
-- Every source is `kind='book'` today, so the badge will correctly read "not
-- available" for video and web until such sources are ingested. That is the
-- point: the UI describes the corpus as it actually is rather than promising
-- links that do not exist. `video_timestamp` already works end to end, so a
-- video source will light up without further schema work.
--
-- Built on the 2026-09-04 bodies recorded in 0047 — normalised Arabic FTS and
-- the halfvec ordering from 0043 are preserved exactly. `search_trigram` is
-- deliberately untouched: it is a retired stub, and 0048 removes its only
-- caller in the edge function rather than reviving it.

-- DROP first: Postgres refuses `create or replace` when the OUT-parameter row
-- type changes ("cannot change return type of existing function"), and adding a
-- column is exactly that. The drop and the create run in one statement batch,
-- so there is no window where search sees a missing function.
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
    score double precision
)
language sql
stable
as $$
    select
        c.id, c.document_id, s.id, s.scholar_id, c.text, c.page_number, c.video_timestamp,
        s.title, s.category, s.kind, s.url, sc.name_translations,
        1 - ((c.embedding::halfvec(1024)) <=> (p_query_embedding::halfvec(1024))) as score
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
    score double precision
)
language sql
stable
as $$
    with q as (select plainto_tsquery('simple', fatwa.normalize_ar(p_query)) tsq)
    select
        c.id, c.document_id, s.id, s.scholar_id, c.text, c.page_number, c.video_timestamp,
        s.title, s.category, s.kind, s.url, sc.name_translations,
        ts_rank_cd(to_tsvector('simple', fatwa.normalize_ar(c.text)), q.tsq) as score
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
