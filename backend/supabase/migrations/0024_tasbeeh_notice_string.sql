-- Adds the Tasbeeh advisory notice to the published string packs so the copy is
-- server-owned (ADR-0011) and can be changed without an app release.
--
-- The apps ship a bundled placeholder as a fallback, so this migration is not
-- required for them to render correctly — it exists so the text becomes
-- *editable*. Setting the value to an empty string hides the notice entirely,
-- which is the intended off switch.
--
-- Clients delta-sync string packs by version, so a new key has to arrive as a
-- NEW published version rather than an in-place edit of the current one —
-- otherwise a client that already has version N would never re-fetch it.

insert into config.string_packs (app_id, locale, version, strings, published)
select
    latest.app_id,
    latest.locale,
    -- Next free version across ALL rows for this (app, locale), published or not.
    -- Using published+1 would collide with an unpublished DRAFT sitting at that
    -- number, and `on conflict do nothing` would then swallow the insert — the
    -- locale would silently never receive the key.
    (
        select max(p2.version) + 1
        from config.string_packs p2
        where p2.app_id = latest.app_id and p2.locale = latest.locale
    ),
    latest.strings || jsonb_build_object('tasbeeh.notice', notice.text),
    true
from (
    -- The currently published pack per (app, locale).
    select distinct on (app_id, locale) app_id, locale, version, strings
    from config.string_packs
    where published
    order by app_id, locale, version desc
) as latest
join (
    values
        ('ar', 'هذا نص تنبيه مؤقت. يمكن تعديله من لوحة التحكم دون تحديث التطبيق.'),
        ('en', 'This is a placeholder notice. It can be edited from the admin dashboard without releasing an app update.')
) as notice(locale, text) on notice.locale = latest.locale
-- Idempotent. Without this, every run would publish yet another version: the run
-- after this one sees the pack it just created and bumps again, forever.
where not (latest.strings ? 'tasbeeh.notice')
on conflict (app_id, locale, version) do nothing;

-- NOTE: if an app has no published string pack yet, this inserts nothing and the
-- apps keep using their bundled placeholder. Create a pack for that locale first
-- (see supabase/seed.sql for the shape) and re-run.
