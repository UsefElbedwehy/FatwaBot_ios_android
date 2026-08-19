-- 0031: bump `version` so already-synced clients actually receive 0028–0030.
--
-- Content delta-sync is version-gated: the app sends
-- `?since_version=<cached>` and the API returns nothing when the stored version
-- is not greater. 0028 (publishing 1,978 entries), 0029 (gradings) and 0030
-- (العمدة stamp) all changed rows **without touching `version`**, so every
-- client that had already cached the collection asked for "anything newer than
-- v1", was correctly told "no", and kept serving its pre-publish snapshot.
--
-- Observed on a real device before this fix: بلوغ المرام opened to an empty
-- reader ("Hadith #0", infinite spinner) while the API served all 1,564
-- entries. Deleting the local cache fixed it, which is what isolated the cause
-- — the fetch was fine, the version gate was not.
--
-- The general rule this encodes: **any migration that changes content a client
-- can cache must bump `version`.** A data fix that is invisible to every
-- existing install is not a fix.

update content.hadith_entries e
set version = e.version + 1
from content.hadith_collections c
where e.collection_id = c.id
  and e.app_id = c.app_id
  and c.slug in ('bulugh_almaram', 'umdat_alahkam');

update content.hadith_collections
set version = version + 1
where slug in ('bulugh_almaram', 'umdat_alahkam');
