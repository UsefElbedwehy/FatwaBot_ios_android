-- Publishes the Tasbeeh advisory notice into the string packs so the copy is
-- server-owned (ADR-0011) and editable from the dashboard without an app release.
--
-- The apps ship a bundled placeholder as a fallback, so this migration is not
-- required for them to render correctly — it exists so the text becomes
-- *editable*. Setting the value to an empty string hides the notice entirely,
-- which is the intended off switch.
--
-- Clients delta-sync string packs by version and read the HIGHEST published
-- version, so a new key has to arrive as a NEW published version. Editing the
-- current one in place would never reach a client that already has it.
--
-- One statement covers every starting state, because the project genuinely has
-- all of them: production had no packs at all, while local/seeded databases have
-- published ones.
--   * published pack exists  -> new version = its strings + the notice
--   * only unpublished drafts -> new published version built on an empty base
--   * no packs whatsoever     -> version 1 containing just the notice
--
-- Two numbering rules that are easy to get wrong (both were real bugs caught by
-- running this against a throwaway Postgres):
--   * the next version is max(version) + 1 across ALL rows, published or not.
--     Using published+1 collides with a draft parked at that number and the
--     insert is silently swallowed by ON CONFLICT.
--   * the guard is on the key's absence, not ON CONFLICT alone. Without it, each
--     run sees the pack the previous run created and publishes another version,
--     forever.

insert into config.string_packs (app_id, locale, version, strings, published)
select
    target.app_id,
    target.locale,
    current_pack.next_version,
    current_pack.base_strings || jsonb_build_object('tasbeeh.notice', target.text),
    true
from (
    -- Every app gets the notice for each shipped locale (schemas are
    -- tenancy-ready per ADR-0015; today this is the single primary app).
    select apps.id as app_id, notice.locale, notice.text
    from public.apps as apps
    cross join (
        values
            ('ar', 'هذا نص تنبيه مؤقت. يمكن تعديله من لوحة التحكم دون تحديث التطبيق.'),
            ('en', 'This is a placeholder notice. It can be edited from the admin dashboard without releasing an app update.')
    ) as notice(locale, text)
) as target
cross join lateral (
    select
        coalesce(
            (
                select max(p.version)
                from config.string_packs p
                where p.app_id = target.app_id and p.locale = target.locale
            ),
            0
        ) + 1 as next_version,
        coalesce(
            (
                select p.strings
                from config.string_packs p
                where p.app_id = target.app_id and p.locale = target.locale and p.published
                order by p.version desc
                limit 1
            ),
            '{}'::jsonb
        ) as base_strings
) as current_pack
-- Idempotent: skip locales whose published pack already carries the key.
where not (current_pack.base_strings ? 'tasbeeh.notice')
on conflict (app_id, locale, version) do nothing;
