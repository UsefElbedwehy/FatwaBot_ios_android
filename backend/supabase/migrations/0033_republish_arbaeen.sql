-- 0033: put الأربعين الإيمانية back in the list (owner decision, 2026-08-01).
--
-- 0032 unpublished it because an empty collection advertising "available soon"
-- promises content with no delivery date. The owner prefers the five
-- collections visible, with the under-review state carrying the honesty — the
-- app already renders a zero-entry collection as non-navigable and dimmed, so
-- nobody taps into a blank reader.
--
-- Content follows in 0034; this restores visibility on its own so the two
-- decisions stay separable in history.

update content.hadith_collections
set published = true,
    version = version + 1      -- clients cache the list; see 0031
where slug = 'arbaeen_imaniyya'
  and not published;
