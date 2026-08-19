# Content verification

Religious text is the product. A mistranslated dua or a mis-graded hadith is worse
than a missing one, so **no text reaches users unreviewed**. This document describes
the review model, the database guarantee that enforces it, and the reviewer
workflow.

Related: [content-import.md](content-import.md) (how text gets in),
[hadith-collections.md](hadith-collections.md).

## The model

Every row in the three text-bearing tables — `content.azkar_items`,
`content.duas`, `content.hadith_entries` — carries a review state and its
provenance (migration [`0014_content_review.sql`](../../backend/supabase/migrations/0014_content_review.sql)):

| Column          | Meaning                                                             |
| --------------- | ------------------------------------------------------------------ |
| `review_status` | `pending` \| `approved` \| `rejected` (default `pending`)          |
| `source_dataset`| Provenance, e.g. `Seen-Arabic morning/evening (MIT)`               |
| `imported_at`   | When the importer last wrote the row                               |
| `reviewed_by`   | Who approved/rejected it (`auto:trusted-import` for import-time)   |
| `reviewed_at`   | When                                                               |
| `review_note`   | Free-text (e.g. "pending scholarly diacritics proofread")          |

## The guarantee

A check constraint on each of the three tables:

```sql
check (not published or review_status = 'approved')
```

A row can be `published = true` **only** when it is `approved`. The content API
serves `published = true` rows, so the constraint makes it structurally
impossible for the API to serve un-approved text — enforced by the database on
every write, not by application convention. An attempt to publish a `pending` or
`rejected` row fails the transaction.

### Importer defaults reinforce this

All three importers (`scripts/{azkar,dua,hadith}_import.ts`) default
`published = false`. A fresh import lands **unpublished and pending** — it cannot
appear in the app until a reviewer both approves and publishes it. Pass
`--source-dataset "<name>"` so the provenance is recorded on every row, and
`--publish` only for already-trusted, already-approved content.

### Why the currently-live content is `auto:trusted-import`

Migration 0013 shipped the azkar + dua libraries imported verbatim from reputable
public-domain sources (Seen-Arabic, Hisn al-Muslim). 0014 reconciles those live
rows to `approved` so they keep serving, but stamps them
`reviewed_by = 'auto:trusted-import'` with a note. That marks them as
"trustworthy enough to ship, not yet human-proofread" — they show up in the
review queue below so a scholar can do a real diacritics/grading pass without
blocking the app.

## Reviewer workflow

Everything still needing eyes is in one view:

```sql
select * from content.needs_review order by kind, imported_at;
```

`content.needs_review` unions all three tables and surfaces anything that is
either `pending` or was only `auto:`-approved on import.

**Approve** a row after proofreading:

```sql
update content.azkar_items
   set review_status = 'approved',
       reviewed_by  = 'sheikh-name',
       reviewed_at  = now(),
       review_note  = 'Diacritics verified against printed Hisn al-Muslim.'
 where id = '<uuid>';
```

**Reject** (keeps it out of the app; the constraint blocks publishing it):

```sql
update content.duas
   set review_status = 'rejected',
       reviewed_by  = 'sheikh-name',
       reviewed_at  = now(),
       review_note  = 'Weak attribution — remove from source dataset.'
 where id = '<uuid>';
```

**Publish** approved content (safe — the constraint permits it only once
approved):

```sql
update content.hadith_entries set published = true where id = '<uuid>';
```

Approving does not auto-publish and publishing does not auto-approve; they are
independent switches so a reviewer can stage approvals and flip visibility
separately.

### Re-import semantics differ by table

- **Hadith** upserts on a natural key `(app_id, collection_id, number)`. A
  re-import updates the text, grading, and `source_dataset` in place via
  `on conflict do update` but **leaves `review_status`, `reviewed_by`, and
  `reviewed_at` untouched** — a previously approved hadith stays approved.
- **Azkar / dua** have no natural item key, so each category is rebuilt
  delete-then-insert. Re-importing a category therefore **resets its items to
  `pending`** (fresh rows take the column default). This is intentional: changed
  text is new text and deserves a fresh look. The category row itself is upserted
  and keeps its state.

So: safe to re-run a hadith importer against approved content; re-running an
azkar/dua importer against a category means re-reviewing that category's items.
