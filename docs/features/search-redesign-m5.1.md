# M5.1 — Search redesign (client feedback, 2026-09-05)

Driven by three pieces of client feedback plus the reference design in
`Search Design Reference/FatwaBotSearch.mp4` and the two screenshots shared on
2026-09-05 (a تخريج الحديث result and a fatwa result from the reference app):

1. **Search is slow.**
2. **The flow is wrong** — the three modes should be selectable filters on the
   search screen itself (first one selected by default), and tapping the text
   field should open the keyboard, not push a separate search page.
3. **The result needs the reference structure** — a summary, per-scholar answer
   cards with evidence, whether the answer is available in other resources
   (YouTube / website / book), a ruling-status circle, and a "contact us" at the
   end.

Ruling circle colour code (client's mapping):

| Colour | Ruling |
| --- | --- |
| 🟢 green | حلال (halal) |
| 🔴 red | حرام (not halal) |
| 🔵 blue | إباحة (mubah) |
| 🟠 orange | كراهة (makruh) |

Open question for the client: the five-fold fiqh scale also has واجب and
مستحب, which this mapping doesn't cover — and many questions (a du'a's wording,
a hadith's grading) have no ruling at all. Plan: the schema carries
`ruling: halal | haram | mubah | makruh | none`; `none` renders no circle.
واجب folds into halal and مستحب into halal unless the client wants two more
colours — ask before shipping.

## Current state (what this builds on)

Measured on production 2026-09-05 (`Server-Timing` on `POST /v1/search`):

```
embed;dur≈130 (cached) / ≈240 (cold) / ≈56000 (Voyage 429, free tier)
search;dur≈500
answer;dur≈13500   ← the cost
```

Corpus at time of writing: 31,912 chunks across 94 sources (all `granted`,
all `kind='book'`, all ابن عثيمين), all embedded. The `halfvec` expression
index covers new rows automatically, so the newly ingested books are already
searchable.

## Supabase findings (from the owner's recent changes) — action needed

Checked 2026-09-05 after the owner's ingest run:

- **Corpus grew 63 → 94 sources, 24,977 → 31,912 chunks** — all embedded, all
  granted. Good; nothing to do.
- ⚠️ **`content.needs_review` exists in the database but in no migration file.**
  This is exactly the drift that made `supabase db push` unsafe before 0042 was
  reconciled. Needs a migration file capturing its DDL (or dropping it if it was
  scratch), then `migration repair`.
- ⚠️ **A test scholar «بيانات اختبار» is active in production** alongside
  ابن عثيمين. If any source rows ever attach to it as `granted`, search will
  cite "test data" to real users. Deactivate it (`active = false`) or delete it.

## Workstream A — speed

The answer model is ~85% of the latency; retrieval is already ~500ms.

1. **Answer cache** (backend). Same pattern as `fatwa.query_embeddings` (0044):
   `fatwa.answer_cache (app_id, question_hash, mode, model) → response JSON`.
   A repeated question skips retrieval *and* the answer model — the whole
   request becomes a hash lookup, well under a second. Devotional questions
   repeat heavily across users, so the hit rate should be substantial.
   Invalidate rows on model change (key) and on corpus growth (add a
   `corpus_generation` column bumped by the ingester, or simply TTL them —
   decide during implementation).
2. **Trim the model's input** (backend). `finalTopN` is 8 chunks; try 6 and cap
   per-chunk characters. Fewer input tokens shortens both time-to-first-token
   and total time. Measure via `Server-Timing` before/after; keep only if
   quality holds on the test questions.
3. **Cap the output.** The reference design is a *structured* card, not an
   essay. The structured schema (Workstream C) naturally bounds answer length,
   which directly cuts generation time.
4. **Voyage billing** (owner action, not code). Free tier ≈ shared
   1–3 req/min; the 56s stalls on cold questions persist until billing is
   enabled. The embedding cache only helps repeats.
5. **Deferred: streaming.** Real perceived-latency win but touches the edge
   function, both clients, and the citation-verify step (which needs the full
   answer before it can verify). Not in M5.1.

## Workstream B — single-page search flow

Android first, then iOS on approval (standing rule: iOS changes need explicit
go-ahead; this is product feedback so presumably both — confirm).

- `SearchHome` becomes the search screen:
  - The three mode cards become **filter chips** — selected/unselected state,
    **فتوى selected by default**. Tapping a chip never navigates.
  - Tapping the text field focuses it and opens the keyboard in place.
  - Submit runs the search on the same screen; loading (the dhikr loading view)
    and results render below the field. «بحث جديد» clears back to idle.
- `FatwaSearchScreen` stops being a pushed destination from Home;
  `WorshipDetailScaffold` push, `homeSearchMode` state and the Home
  `BackHandler` path go away (Home's back-to-idle replaces them).
- `FatwaSearchViewModel` keeps the state machine; it gains a `mode` that can
  change between searches instead of being fixed at construction.
- Deep links / content-focus routes must keep working (they currently target
  the pushed screen).

## Workstream C — structured result

### Backend: extend the answer contract

`ANSWER_JSON_SCHEMA` (providers.ts) and the response of `POST /v1/search` gain:

```jsonc
{
  "summary": "خلاصة الأقوال ...",        // the dark-maroon top card
  "ruling": "halal|haram|mubah|makruh|none",
  "scholar_answers": [                     // N supported; corpus has 1 today
    {
      "scholar": "ابن عثيمين",
      "answer": "...",
      "evidence": "الدليل ...",           // the inset الدليل sub-card
      "citations": [ /* existing citation shape */ ]
    }
  ],
  // hadith mode instead fills:
  "hadith": {
    "text": "...", "grade": "لا أصل له بهذا اللفظ",
    "source": "...", "scholar_verdicts": "أقوال العلماء ..."
  },
  "resources": [                           // availability chips, from citations
    { "kind": "book|video|website", "available": true, "url": null }
  ]
}
```

- Citation verification is unchanged in principle and now runs per
  `scholar_answers[].citations` — the anti-fabrication gate stays.
- `resources` is **derived server-side from the verified citations**, not asked
  of the model: a citation's source row carries `kind` and `url`
  (`fatwa.sources.url` exists). Today every source is a book, so the reference
  design's "متاح على يوتيوب" will honestly read غير متاح until video sources are
  ingested — the schema is ready for them (`video_timestamp` already works
  end-to-end).
- Multi-scholar cards (ابن باز + ابن عثيمين in the reference) need *content*,
  not code: the schema takes N scholars, retrieval already returns scholar per
  chunk. Until more scholars' works are licensed and ingested there will be one
  card. Licensing remains paused — this plan does not resume it.
- The old flat `answer` field stays populated (concatenated) for one release so
  an un-updated client still renders something.
- `answers_log` stores the structured JSON as-is.

### Clients: render the reference layout

Result view (both platforms, Android first):

1. **خلاصة الأقوال** — summary in a filled maroon card, with the **ruling
   circle** (colour per the table; absent when `none`).
2. **Per-scholar cards** — header (name + رحمه الله) + availability badge,
   answer text (Markdown-rendered — Android has `MarkdownText`, iOS needs
   `AttributedString(markdown:)`), inset **الدليل** card.
3. **Hadith mode** — نص الحديث + status dot, درجة الحديث, المصدر,
   أقوال العلماء as separate fields (per screenshot 1).
4. **المصادر** — existing citation cards, now grouped under their scholar.
5. **بحث جديد** button.
6. **Disclaimer + تواصل معنا** — the reference's تنبيه line ("this tool is
   educational and does not replace consulting scholars directly") and a
   contact button reusing the Settings contact links.

## Sequencing

| # | What | Where |
| --- | --- | --- |
| 1 | Migration for `content.needs_review` + deactivate test scholar | backend/db |
| 2 | Answer cache + input trim (A1, A2) — measurable win, no UI dependency | backend |
| 3 | Structured answer schema + resources derivation + tests (C backend) | backend |
| 4 | Single-page flow (B) + structured result view (C) on Android, verified on emulator | android |
| 5 | Same on iOS after explicit go-ahead | ios |
| 6 | Owner: Voyage billing; client: confirm ruling-colour mapping for واجب/مستحب | external |

Steps 2–3 are independent of 4; backend ships first so the client change is a
pure renderer.
