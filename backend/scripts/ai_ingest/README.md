# M5 ingestion pipeline — PDF corpus → OCR'd Markdown

Turns the scanned `M5 Data/` corpus (312 books, 159,421 pages) into per-book Markdown
files ready for the chunk/embed/load step, which lives in the Deno backend proper
(`backend/functions/api/ai_search/`, not here — see
[docs/features/ai-search-m5.0-spec.md](../../../docs/features/ai-search-m5.0-spec.md)).

This directory only does steps 1–3 of that spec's pipeline: **render → OCR →
assemble**. Zero Python dependencies beyond the standard library + `pdftoppm`
(poppler-utils, already installed on this machine) — nothing to `pip install`.

## Status

- `render_pages.py`, `ocr_batch.py` — built and tested (page ordering, Markdown
  assembly, and cache-based resumability all verified with a mocked provider —
  no network, no cost). **Not yet run against a real provider API** — that needs a
  key (see below).
- `pilot_output/markdown/*.md` — 3 pages **hand-transcribed by reading the actual
  page images**, one from each of 3 structurally different books (a footnoted/ayah
  page, a Q&A-format fatwa page, a prose commentary page). This is the ground truth
  the automated pilot gets compared against, and it's what grounded the spec's
  chunking-boundary decisions (`❋ ❋ ❋` dividers, س/ج pairs, footnote handling).

## Run the automated pilot (next step, needs a key)

```bash
export GEMINI_API_KEY=...   # or MISTRAL_API_KEY / ANTHROPIC_API_KEY

python3 render_pages.py "../../../M5 Data/العقيدة/شرح ثلاثة الأصول - ابن عثيمين.pdf" \
    --out pilot_output/pages --start 25 --end 27

python3 ocr_batch.py "pilot_output/pages/شرح ثلاثة الأصول - ابن عثيمين" \
    --provider gemini \
    --out pilot_output/markdown/aqidah-sample.gemini.md \
    --source-label "العقيدة/شرح ثلاثة الأصول - ابن عثيمين.pdf"
```

Repeat for the fatawa/hadith samples (page ranges 30–32 and 15–17 respectively, same
books) and for a second provider, then diff each result against the matching
hand-transcribed file in `pilot_output/markdown/` — that's the quality-per-dollar
comparison the spec's Build Order step 1 calls for.

## Run the full corpus (after the pilot picks a provider)

Per book:
```bash
python3 render_pages.py "<pdf path>" --out pages/
python3 ocr_batch.py "pages/<book-stem>" --provider <chosen> \
    --out markdown/<book-stem>.md --source-label "<original relative path>"
```

At 312 books / 159k pages this is hours, not minutes — `--workers` controls
concurrency (mind each provider's rate limits), and `--cache` means a crashed or
rate-limited run resumes for free. A thin shell loop over `find "M5 Data" -iname
'*.pdf'` driving both scripts per book is the natural driver; not written yet since
the provider pick (and its rate limits) should decide the concurrency/batching
shape first.

## What happens after this directory

`markdown/*.md` is exactly `fatawa.documents.original_text` per book, page markers
intact. Loading, chunking, embedding, and indexing happen in the Deno backend
(`ai_search/chunking.ts` etc.), not here — this directory's output is the input to
that, nothing more.
