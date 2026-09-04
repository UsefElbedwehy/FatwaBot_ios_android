-- Cache the whole answer, not just its embedding.
--
-- Measured on production (`Server-Timing` on POST /v1/search):
--
--   embed;dur=130     (cached since 0044)
--   search;dur=500    (since the halfvec index in 0043)
--   answer;dur=13500  <- 85% of the request
--
-- 0044 removed the embedding call for a repeated question. This removes the
-- other two stages as well: a hit is one indexed lookup and the request returns
-- in well under a second instead of ~15s. Devotional questions repeat heavily
-- across users, which is what makes this worth the storage.

create table if not exists fatwa.answer_cache (
    app_id uuid not null references public.apps (id) on delete cascade,
    -- SHA-256 of the normalised question — same hashing as
    -- fatwa.query_embeddings, so spacing and diacritic variants share an entry.
    question_hash text not null,
    -- Part of the key: the same question asked in `fatwa` vs `hadith` mode is a
    -- different prompt and a different answer.
    mode text not null,
    -- Also part of the key. A model change must miss rather than keep serving
    -- the previous model's wording under the new model's name.
    model text not null,
    -- The response body exactly as it was returned, so a hit needs no
    -- re-derivation and can never drift from what a miss would produce.
    response jsonb not null,
    -- The corpus revision this answer was generated against; see
    -- fatwa.corpus_state below.
    corpus_generation integer not null,
    created_at timestamptz not null default now(),
    last_used_at timestamptz not null default now(),
    hits integer not null default 0,
    primary key (app_id, question_hash, mode, model)
);

create index if not exists answer_cache_last_used_idx
    on fatwa.answer_cache (app_id, last_used_at);

-- Exact invalidation, rather than a TTL that is a guess in both directions.
--
-- An answer is only as good as the chunks it was grounded in, so the event that
-- should invalidate it is the corpus changing — not the passage of time. A TTL
-- long enough to be worth having would keep serving a stale refusal for days
-- after the book that answers it was ingested; a TTL short enough to avoid that
-- would throw away most of the benefit.
--
-- The ingester bumps this after a successful load, and a cache row is only a
-- hit when its generation still matches. Reads cost nothing extra: the lookup
-- filters on a subquery against this one-row table in the same statement.
create table if not exists fatwa.corpus_state (
    app_id uuid primary key references public.apps (id) on delete cascade,
    generation integer not null default 1,
    updated_at timestamptz not null default now()
);

insert into fatwa.corpus_state (app_id, generation)
select id, 1 from public.apps
on conflict (app_id) do nothing;
