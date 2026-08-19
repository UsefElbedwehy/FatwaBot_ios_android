-- 0032: stop advertising الأربعين الإيمانية until it has content.
--
-- 0025 created the collection with **zero entries**, pending a decision on
-- محمد بن شمس الدين's compilation: the individual hadith are public domain, but
-- his *selection* of which forty is a modern copyrighted work. That decision is
-- still open, so no content is scheduled to arrive.
--
-- Meanwhile the app rendered it as "قيد المراجعة العلمية — ستتوفر قريباً"
-- (under review — available soon), which promises something nobody has
-- committed to delivering. An honest empty state for content that IS coming is
-- useful; the same state for content with no path to arrival is a false promise.
--
-- Unpublished rather than deleted: the row, its name and description survive, so
-- publishing it again once the licensing question is settled — or once a
-- classically-sourced forty is agreed — is a one-line change, not a re-import.
--
-- Idempotent.

update content.hadith_collections
set published = false,
    version = version + 1      -- clients cache the list; see 0031
where slug = 'arbaeen_imaniyya'
  and published;
