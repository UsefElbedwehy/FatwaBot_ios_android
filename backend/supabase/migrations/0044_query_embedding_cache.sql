-- Cache the embedding of a question, so asking it again costs no provider call.
--
-- Measured on production: the embedding stage takes 238ms after an idle gap and
-- ~56s for anything issued within the following minute, because the Voyage key
-- is on a free tier and returns 429 (see `Server-Timing` on POST /v1/search).
-- A repeated question now skips that call entirely.
--
-- This does not lift the rate limit — the first person to ask any given question
-- still pays for it, and on a free tier concurrent cold questions still queue.
-- It reduces call volume, which matters on any tier; billing is what removes the
-- ceiling.
--
-- The corpus ingester already caches embeddings the same way, to a local
-- `.embedding_cache.json`. This is that idea, server-side, for query vectors.

create table if not exists fatwa.query_embeddings (
    app_id uuid not null references public.apps (id) on delete cascade,
    -- SHA-256 of the *normalised* question, so spacing, tatweel and diacritic
    -- differences all land on one row. Storing the hash rather than the text
    -- keeps the key fixed-width and keeps user-typed content out of a table
    -- that exists purely as a performance aid.
    question_hash text not null,
    -- Part of the key, not just a column: vectors from different models are not
    -- comparable, so a model change must miss rather than silently serve
    -- embeddings the index was not built from.
    model text not null,
    embedding vector(1024) not null,
    created_at timestamptz not null default now(),
    last_used_at timestamptz not null default now(),
    hits integer not null default 0,
    primary key (app_id, question_hash, model)
);

-- For eviction: the cache grows with distinct questions and never shrinks on its
-- own. Nothing prunes it yet — at a few hundred bytes per row that is fine for a
-- long while, and an LRU sweep can be added on this index when it isn't.
create index if not exists query_embeddings_last_used_idx
    on fatwa.query_embeddings (app_id, last_used_at);
