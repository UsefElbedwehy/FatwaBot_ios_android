# M5.2 — Search quality (2026-09-06)

Follow-up to the M5.1 redesign, driven by one number: **31 of the first 59
searches refused** — fatwa 19/45, hadith 7/9, general 5/5. Every one of them
had retrieved eight chunks, so retrieval never came back empty; the refusals
happened between the model and the verifier. Everything below is backend only
(migration `0050`, the edge function); neither client changes.

## What was wrong

Read from `fatwa.answers_log` once 0050 started recording `refusal_reason`
and `dropped_citations`:

1. **The verifier rejected honest quotes.** The corpus is OCR'd with an error
   roughly every fifth word (`docs/features/corpus-ocr-audit.md`). A model told
   to copy verbatim reads «فمن خلق لحيته فقد عصي امر النبي كيه» and writes
   «من حلق لحيته فقد عصى أمر النبي» — correct, and not a substring. Five of
   six citations on «ما حكم حلق اللحية» died this way; the sixth was luck.
2. **FTS gated on the wrong word.** `plainto_tsquery` ANDs every token, and
   «حكم» is in most of a fatwa corpus. «ما حكم حلق اللحية» matched 34 chunks;
   «حلق اللحية» matched 61.
3. **Hadith mode searched the wrong corpus.** The fatwa books are one scholar's
   shelf, not a hadith collection. Meanwhile `content.hadith_entries` held
   36,183 hadiths (20,972 graded), imported for the app's hadith feature and
   never searched.
4. **Two normalisers disagreed.** The database's `normalize_ar` folds ة→ه; the
   edge function's `normalizeArabic` did not. So «حلق اللحيه» and
   «ما حكم حلق اللحية؟» were different cache keys and different verifier
   inputs.
5. **Nothing said why a refusal happened.** The log kept only citations that
   survived, so "the model declined" and "the verifier dropped everything"
   were the same row.

## What changed

| Change | Where |
| --- | --- |
| `refusal_reason` (`model_refused` / `all_citations_dropped` / `no_chunks`) and `dropped_citations` on `answers_log` | 0050, `handlers/search.ts` |
| Quote repair: a citation that is not an exact substring is matched word-by-word with one edit of tolerance per word (two at seven letters); the longest shared run of ≥ 6 words replaces the quote, **as the source's own words**. Under six, or under 40 % of the quote, it is dropped as before. | `citation_verify.ts` |
| Question-frame words (ما، حكم، هل، صحة، …) stripped before the lexical legs; the vector leg still sees the whole question | `retrieval.ts` |
| `content.search_hadith` + GIN index; hadith mode adds that leg and its hits lead the result | 0050, `retrieval.ts` |
| `ocr_shattered` returned per chunk by both search functions (computed on the 30 rows returned, not stored); fused score ×0.5 for a shattered chunk. Candidate pools 20 → 30 | 0050, `retrieval.ts` |
| `normalizeArabic` folds ة→ه | `text_normalize.ts` |
| `summary` and `scholarAnswers` required in the answer schema; `answer` optional and derived server-side; quotes capped at 20 words, four per answer | `providers.ts` |
| Citation locators (page / hadith number / timestamp) taken from the retrieved chunk, not the model | `handlers/search.ts` |
| Hadith card built from the cited entry when the model omits it, preferring a graded entry | `handlers/search.ts` |
| An "empty success" (non-refusal with no summary, card or hadith) is returned but never cached; contract version 2 → 3 | `answer_cache.ts`, `handlers/search.ts` |
| `Server-Timing` gains `repaired;dur=N` — the count of citations that needed repair — and, from the speed pass, `tokens`, `input` and `ttft` | `handlers/search.ts` |

### Why repair is still anti-fabrication

The displayed quote is always the chunk's own words, never the model's. What
repair accepts is a claim that *six consecutive source words, in order, each
within one edit* match what the model wrote — which cannot be produced without
having read the chunk. The floor is six rather than eight because eight never
triggered on this corpus: measured on real dropped citations, the longest
exact run between an honest quote and its scan was four or five words.

What repair does **not** do is fold letters that change meaning. خ/ح is
tolerated as a one-edit word difference inside a six-word run, not as a
normalisation — خلق and حلق remain different words everywhere else.

### Two things learned the hard way during the rollout

- **Making `answer` optional with nothing else required produced empty
  answers.** The first deploy came back as one citation and no summary, card
  or hadith. `summary` and `scholarAnswers` are now required; a refusal writes
  `""` and `[]`, so nothing is forced.
- **Those empty bodies were cached** because they were not refusals. Hence the
  empty-success guard and the contract bump.

## Measured

Same questions, production, before → after (`refused` / verified citations):

| Question | Before | After |
| --- | --- | --- |
| ما حكم حلق اللحية؟ | refused, 0 | `haram`, 3 (3 repaired) |
| ما حكم قول توكلت على الله ثم عليك؟ | refused, 0 | answered, 3 (3 repaired) |
| هل يجوز للمحرم لبس الكمامة؟ | refused, 0 | answered, 2 |
| ما حكم صيام يوم عرفة لغير الحاج؟ | answered | `mustahabb`, 4 |
| ما صحة حديث إنما الأعمال بالنيات (hadith) | refused | card «صحيح - متفق عليه», البخاري رقم 1 |
| الجنة تحت أقدام الأمهات (hadith) | refused | refused — correctly: that wording is in none of the six books |

## Speed pass (same day)

The answer step was 17–34 s. The obvious levers were tried first and
**did nothing**: `finalTopN` 8 → 6, chunk text capped at 2,000 characters
(sentence boundary), hard word budgets on the summary and cards, no volunteered
`hadith` object outside hadith mode. Output fell to ~900 tokens; `answer;dur`
stayed at 22–31 s. Sequential runs ruled out rate limiting.

Instrumenting the call (streamed via the SDK, `ttft`, `input`, `tokens` added
to `Server-Timing`) showed why: time-to-first-token was ~2 s on 11k input
tokens — reach and prompt processing were fine — and generation was running at
**~40 tokens/s**. The one thing on that path that is not ordinary generation
is the JSON-schema constrained decoding (`output_config.format`).

A/B on production, same question, cold, one at a time:

| | `answer;dur` | `ttft` | output tok/s | result |
| --- | --- | --- | --- | --- |
| structured outputs (schema) | 25.3 s | 2.1 s | ~40 | `haram`, 3 citations |
| JSON requested in the prompt | **12.0 s** | 0.95 s | ~93 | `haram`, 3 citations |

Prompt-requested JSON is now the default (`AnswerJsonMode`), with the schema in
the prompt, `parseAnswerJson` sanitising the body (fences, prose, an
out-of-enum ruling → `none`), and a one-shot retry in schema mode if the body
does not parse. `ANSWER_JSON_MODE=schema` forces the old path. Whole-request
time for a cold fatwa question went from ~27 s to ~13 s; a cached repeat is
still ~1–2 s.

The length levers stay in — they are correct on their own terms and cost
nothing — but they are not what moved the number. Streaming to the client is
the next lever: the summary is generated first and could be on screen in
~2 s.

## Not done

- `general` mode (5/5 refused) is unchanged. Those questions («متى توفي
  الرسول») are sīrah, not fiqh; the corpus cannot answer them and the honest
  fix is content, not code.
- The 48 clean local books the audit found unloaded, and the 7 wrecked books
  with clean copies on disk, are still not loaded — that was declined
  ("no dont upload") and is the single largest remaining recall lever.
- Voyage billing: cold questions still occasionally pay a 429 backoff
  (`embed;dur=76294` observed once during this rollout).
