-- Titles for azkar and du'a entries.
--
-- The reader currently shows a wall of near-identical cards distinguished only
-- by their source line, which makes a category like أذكار الصباح (26 entries)
-- hard to navigate and impossible to scan for a specific dhikr. A title gives
-- each card an identity — "شكر الله على رد الروح" — and gives search something
-- to match that is not the full matn.
--
-- ## Why additive and defaulted
-- Every layer above this — the API serializer, both apps' models, both readers —
-- is unchanged at the time this lands. An empty jsonb default means existing
-- rows stay valid, existing queries keep working, and the column is simply
-- unread until the stack catches up. Nothing about this migration requires a
-- coordinated deploy.
--
-- ## Why translations rather than a plain text column
-- Matches `name_translations` on the categories and every other user-facing
-- string in the content domain. A title is read aloud from the screen in the
-- user's language; making it single-locale here would be the one exception in
-- the schema and would have to be undone the first time the app ships in
-- English properly.
--
-- Titles themselves are NOT set here. They are religious content and get their
-- own reviewed migration, sourced from the standard حصن المسلم headings rather
-- than authored — the same gate the hadith corpus went through.

alter table content.azkar_items
    add column if not exists title_translations jsonb not null default '{}'::jsonb;

alter table content.duas
    add column if not exists title_translations jsonb not null default '{}'::jsonb;
