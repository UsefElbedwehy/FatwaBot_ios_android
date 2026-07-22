-- 0014: content verification structure (docs/features/content-verification.md).
--
-- Religious text must never reach users unreviewed. This adds a review state +
-- provenance to the three text-bearing content tables and a DB-level guarantee:
--   a row can be published ONLY when review_status = 'approved'.
-- The content API already serves `published = true`, so with this check
-- constraint it can only ever serve approved text — enforced on write, not by
-- convention.

do $$
declare tbl text;
begin
  foreach tbl in array array['azkar_items', 'duas', 'hadith_entries'] loop
    execute format($f$
      alter table content.%I
        add column if not exists review_status text not null default 'pending'
          check (review_status in ('pending', 'approved', 'rejected')),
        add column if not exists source_dataset text not null default '',
        add column if not exists imported_at timestamptz not null default now(),
        add column if not exists reviewed_by text,
        add column if not exists reviewed_at timestamptz,
        add column if not exists review_note text not null default '';
    $f$, tbl);
  end loop;
end $$;

-- Reconcile what's already live (migration 0013 published azkar + dua verbatim
-- from reputable public-domain sources). Mark it approved so it stays visible,
-- but stamp reviewed_by='auto:trusted-import' + a note so a human proofread pass
-- can find everything that hasn't yet had real scholarly review.
update content.azkar_items set
  review_status = 'approved',
  reviewed_by = 'auto:trusted-import',
  reviewed_at = now(),
  source_dataset = 'Seen-Arabic morning/evening (MIT) + Hisn al-Muslim',
  review_note = 'Imported verbatim from a reputable public-domain source; pending scholarly diacritics proofread.'
where published and review_status <> 'approved';

update content.duas set
  review_status = 'approved',
  reviewed_by = 'auto:trusted-import',
  reviewed_at = now(),
  source_dataset = 'Hisn al-Muslim (rn0x/Adhkar-json) — Arabic matn',
  review_note = 'Imported verbatim from a reputable public-domain source; pending scholarly diacritics proofread.'
where published and review_status <> 'approved';

-- The guarantee: cannot publish content that isn't approved. Added after the
-- reconcile above so existing published rows already satisfy it.
alter table content.azkar_items
  add constraint azkar_items_publish_requires_approval check (not published or review_status = 'approved');
alter table content.duas
  add constraint duas_publish_requires_approval check (not published or review_status = 'approved');
alter table content.hadith_entries
  add constraint hadith_entries_publish_requires_approval check (not published or review_status = 'approved');

-- Convenience view: everything a reviewer should still look at — pending items,
-- plus anything that was only auto-approved on import (never human-verified).
create or replace view content.needs_review as
  select 'azkar' as kind, id, category_id::text as parent_id, arabic_text, source,
         review_status, source_dataset, reviewed_by, review_note, imported_at
    from content.azkar_items
   where review_status = 'pending' or reviewed_by like 'auto:%'
  union all
  select 'dua', id, category_id::text, arabic_text, source,
         review_status, source_dataset, reviewed_by, review_note, imported_at
    from content.duas
   where review_status = 'pending' or reviewed_by like 'auto:%'
  union all
  select 'hadith', id, collection_id::text, arabic_text, source,
         review_status, source_dataset, reviewed_by, review_note, imported_at
    from content.hadith_entries
   where review_status = 'pending' or reviewed_by like 'auto:%';

grant select on content.needs_review to service_role;
