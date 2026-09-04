-- Two pieces of hygiene found by auditing the live database against these files.

-- 1. `content.needs_review` existed in production with no migration describing
--    it — created out-of-band (first row imported 2026-07-22), holding 34,525
--    rows of hadith/dua/azkar staged for review. Real data, not scratch.
--
--    This is the same class of drift that made `supabase db push` unsafe before
--    0042 was reconciled: a table the files don't know about is a table the next
--    migration can collide with, and a fresh environment can't be rebuilt from
--    this repo. Captured exactly as it exists — deliberately not "improved" —
--    because silently adding constraints to a 34k-row table under the guise of
--    writing down what is already there is how you break an import at 3am.
--
--    Known gaps, left as-is and worth a follow-up: no primary key on `id`, no
--    index on `review_status`/`kind` (the columns any review UI would filter
--    on), and every column nullable.

create table if not exists content.needs_review (
    kind text,
    id uuid,
    parent_id text,
    arabic_text text,
    source text,
    review_status text,
    source_dataset text,
    reviewed_by text,
    review_note text,
    imported_at timestamptz
);

-- 2. A placeholder scholar «بيانات اختبار» ("test data") was active in
--    production. It carries no sources today, so nothing could surface through
--    it — but `search_vector`/`search_fts`/`search_trigram` gate on
--    `sc.active`, so the only thing standing between a test row and a cited
--    answer was that nobody had attached one. Deactivating costs nothing and
--    removes the possibility rather than relying on it not happening.
--
--    Deactivated rather than deleted: a delete would cascade to any sources
--    later attached to it, and there is no reason to take that risk for a row
--    that is inert once inactive.

update fatwa.scholars
set active = false
where name_translations->>'ar' = 'بيانات اختبار';
