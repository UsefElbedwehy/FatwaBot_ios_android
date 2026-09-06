# Corpus OCR audit — 2026-09-06

Scoping exercise for a re-OCR, prompted by «ما حكم حلق اللحية؟» returning a
refusal. Retrieval was not at fault: vector search returned the relevant chunk
at rank 4 (score 0.690). The chunk was unusable because the OCR text is
corrupted, and the answer model is required to quote verbatim from retrieved
text while the citation verifier gates on an exact normalised substring match.
Against garbled source that gate cannot be satisfied, so the model refuses —
correct behaviour, wrong input.

This audit measures how much of the corpus is in that state.

## Method

The signal is **structural, not lexical**: the share of a source's chunks
containing three or more consecutive isolated single Arabic letters — the
signature of a page that OCR shattered rather than read. A secondary column
reports the mean share of non-space characters that are Arabic letters.

```sql
select s.title, count(*) as chunks,
       round(100.0 * count(*) filter (
         where c.text ~ '(^|[[:space:]])[ء-ي][[:space:]]+[ء-ي][[:space:]]+[ء-ي]([[:space:]]|$)'
       ) / count(*), 1) as shatter_pct,
       round(avg(length(regexp_replace(c.text, '[^ء-ي]', '', 'g'))::numeric
                 / nullif(length(regexp_replace(c.text, '[[:space:]]', '', 'g')), 0)) * 100, 1) as arabic_pct
from fatwa.chunks c
join fatwa.documents d on d.id = c.document_id
join fatwa.sources s on s.id = d.source_id
where s.active
group by s.title order by shatter_pct desc;
```

### Metrics that were tried and rejected

Recorded because each looked convincing and each was wrong — an OCR-quality
number is easy to fabricate accidentally.

- **Unknown-word rate against a corpus-derived vocabulary.** Produced a narrow
  65–81% band with no outliers. Meaningless: the threshold measures how much
  vocabulary a book has, not how damaged it is.
- **Near-miss rate** (unattested token one edit from a frequent word — the
  يفول/يقول, قضيلة/فضيلة shape). Ranked books 1.3–4.4%, but inspecting the
  flagged tokens showed they are overwhelmingly *real words*: ملحوظة, دعواه,
  المتهم, الزرعي, لقراءة. Arabic morphology puts many legitimate words one edit
  from a common one. This is a false-positive floor, not corruption.
- **Low-Arabic-density lines.** Flags publisher colophons — ISBNs, telephone
  numbers, Dewey codes — which are correctly OCR'd and merely numeric.
- **Orphan diacritics.** The character class `[ً-ٰ]` spans U+064B–U+0670, which
  contains the Arabic-Indic digits U+0660–U+0669. It was counting the ١٤٣٨ in
  every copyright page.

The shatter metric survives because its false-positive rate is near zero: a
run of isolated letters has no legitimate cause in prose. It was calibrated in
both directions against actual chunk text — see the samples below.

## Result

| Tier | Books | Chunks | Share of corpus |
| --- | --- | --- | --- |
| Wrecked (≥15% of chunks shattered) | 73 | 27,014 | **84.7%** |
| Marginal (5–15%) | 10 | 2,234 | 7.0% |
| Clean (<5%) | 11 | 2,664 | 8.3% |
| Total | 94 | 31,912 | |

Corruption is per-chunk, not per-book: a book at 35% has readable chunks
interleaved with destroyed ones.

Worst — «نبذة في العقيدة الإسلامية», 88.2%:

```
ل بح »+ امات
ا" 7 و بل 6
مدع“ .م قد مف دص ا معات مم عتمم كه ممصم ماه خماهحص كن
```

Mid — «دروس وفتاوى من الحرمين الشريفين١٢», 35.2%, two chunks from the same book:

```
أما صبغ اللحية بالسوادٍ فإنه محرعٌ؛ لأن النبي كله يقول: «غَيَرُوا هَذَا …
```
```
فيجنون أ اا ال 9 له يتان 2 2
```

Clean — «فتاوى نور على الدرب 05», 1.2%:

```
ولكن الذي أراه أنا أن ذلك ليس من باب الاستحباب؛ لأن الاستحباب حكم شرعيء
```

(That book still shows a systematic ة→ء substitution — شرعيء for شرعية — which
is mild enough to leave alone for now but will defeat an exact-substring
citation match on any quote containing it.)

## Two fixes that need no OCR at all

`backend/scripts/ai_ingest/pilot_output/markdown/` holds 62 transcriptions from
the original pilot that are **clean** — zero shattered runs across 360,792
tokens, by the same detector that finds 84.7% of the database wrecked. They are
a different, better transcription pass than whatever produced the current rows.

1. **7 wrecked books already have a clean copy on disk** (399 chunks):
   نبذة في العقيدة الإسلامية (88.2%), شرح ثلاثة الأصول (79.7%),
   مذكرة على العقيدة الواسطية (70.2%), القواعد المثلى (67.5%),
   عقيدة أهل السنة والجماعة (65.2%), فتح رب البرية (56.1%),
   مباحث في أصول الدين (50.0%). `load_corpus.ts` keys source identity on the
   `<!-- source: -->` path (`load_corpus.ts:91`), so re-running it over these
   files upserts onto the same rows rather than duplicating them.

2. **48 clean local books were never loaded at all** — 269,113 tokens: 31 fiqh,
   9 general, 5 hadith, 2 tafsir, 1 language. The database holds only two
   categories, العقيدة (31) and الفتاوى واللقاءات (63). This is the likeliest
   single cause of poor answers on practical questions: the corpus has almost no
   clean fiqh in it, while صفة الحج, رسالة في حكم تارك الصلاة,
   رسالة في الأذكار and 45 others sit unused on disk.

Both are re-ingests of already-transcribed text, so they do not restart OCR.
They do re-embed, which costs Voyage calls — the loader's `--cache` makes
unchanged text free, but this text is new to the cache.

**Licensing gate:** every source is already `license_status='granted'`, so
loading the 48 changes no licensing posture. The M5 OCR pause (2026-08-23)
covers transcribing *new* material, which item 3 below would be. Items 1 and 2
do not touch it. Confirm before acting either way.

3. **The remaining 66 wrecked books need a genuine re-OCR** — a better engine or
   a post-OCR Arabic correction pass. That is the paused workstream.

## Per-book results

`shatter%` = share of the source's chunks containing a shattered-letter run.
`fix` = `reload` if a clean transcription already exists on disk, `re-OCR` if not,
`—` if the book is already clean.

| shatter% | arabic% | chunks | fix | title |
| --- | --- | --- | --- | --- |
| 88.2 | 68.7 | 34 | reload | نبذة في العقيدة الإسلامية ابن عثيمين |
| 79.7 | 67.4 | 128 | reload | شرح ثلاثة الأصول - ابن عثيمين |
| 70.2 | 73.5 | 47 | reload | مذكرة على العقيدة الواسطية ابن عثيمين |
| 67.5 | 69.3 | 83 | reload | القواعد المثلى في صفات الله تعالى وأسمائه الحسنى ابن عثيمين |
| 65.6 | 70.9 | 125 | re-OCR | تعليق مختصر على كتاب لمعة الاعتقاد ابن عثيمين |
| 65.2 | 71.5 | 23 | reload | عقيدة أهل السنة والجماعة ابن عثيمين |
| 64.3 | 66.8 | 112 | re-OCR | تقريب التدمرية - ابن عثيمين |
| 60.0 | 68.9 | 425 | re-OCR | شرح تقريب التدمرية - ابن عثيمين |
| 58.8 | 71.6 | 337 | re-OCR | شرح الكافية الشافية لابن القيم٤ ابن عثيمين |
| 57.6 | 66.7 | 132 | re-OCR | شرح كشف الشبهات - ابن عثيمين |
| 56.7 | 71.5 | 351 | re-OCR | شرح عقيدة أهل السنة والجماعة ابن عثيمين |
| 56.1 | 69.6 | 66 | reload | فتح رب البرية بتلخيص الحموية ابن عثيمين |
| 55.6 | 69.0 | 90 | re-OCR | فتاوى الصيد والرحلات البرية ابن عثيمين |
| 54.5 | 75.2 | 88 | re-OCR | تعليقات وتنبيهات على العقيدة السفارينية ابن عثيمين |
| 54.4 | 72.5 | 461 | re-OCR | شرح الكافية الشافية لابن القيم٢ ابن عثيمين |
| 54.4 | 73.1 | 364 | re-OCR | شرح العقيدة التدمرية لابن تيمية ابن عثيمين |
| 53.1 | 68.9 | 429 | re-OCR | شرح القواعد المثلى - ابن عثيمين |
| 51.6 | 70.9 | 411 | re-OCR | لقاءات الباب المفتوح 03 ابن عثيمين |
| 51.4 | 73.7 | 399 | re-OCR | دروس وفتاوى من الحرمين الشريفين٦ ابن عثيمين |
| 51.2 | 71.1 | 502 | re-OCR | لقاءات وفتاوى الأقليات المسلمة ابن عثيمين |
| 50.0 | 75.6 | 18 | reload | مباحث في أصول الدين - ابن عثيمين |
| 48.8 | 74.3 | 430 | re-OCR | شرح الكافية الشافية لابن القيم٣ ابن عثيمين |
| 48.7 | 74.1 | 359 | re-OCR | التعليق على مواضع من شرح العقيدة الطحاوية ابن عثيمين |
| 48.6 | 75.8 | 288 | re-OCR | دروس وفتاوى من الحرمين الشريفين١٠ ابن عثيمين |
| 47.3 | 70.8 | 402 | re-OCR | شرح فتح رب البرية بتلخيص الحموية ابن عثيمين |
| 45.1 | 77.4 | 355 | re-OCR | شرح الكافية الشافية لابن القيم١ ابن عثيمين |
| 44.7 | 74.9 | 537 | re-OCR | دروس وفتاوى من الحرمين الشريفين١ ابن عثيمين |
| 44.4 | 70.3 | 446 | re-OCR | شرح العقيدة الواسطية - ابن عثيمين |
| 44.4 | 71.7 | 329 | re-OCR | لقاءات الباب المفتوح 08 ابن عثيمين |
| 44.1 | 72.9 | 458 | re-OCR | دروس وفتاوى من الحرمين الشريفين٤ ابن عثيمين |
| 44.1 | 75.5 | 519 | re-OCR | دروس وفتاوى من الحرمين الشريفين٢ ابن عثيمين |
| 42.9 | 72.6 | 359 | re-OCR | لقاءات الباب المفتوح 06 ابن عثيمين |
| 42.7 | 69.8 | 328 | re-OCR | لقاءات الباب المفتوح 10 ابن عثيمين |
| 41.9 | 74.9 | 377 | re-OCR | دروس وفتاوى من الحرمين الشريفين٩ ابن عثيمين |
| 41.8 | 75.4 | 615 | re-OCR | فتاوى سؤال على الهاتف١ ابن عثيمين |
| 41.7 | 68.6 | 636 | re-OCR | القول المفيد على كتاب التوحيد ابن عثيمين |
| 41.6 | 75.1 | 459 | re-OCR | دروس وفتاوى من الحرمين الشريفين٨ ابن عثيمين |
| 41.5 | 71.8 | 354 | re-OCR | لقاءات الباب المفتوح 07 ابن عثيمين |
| 41.3 | 73.4 | 465 | re-OCR | دروس وفتاوى من الحرمين الشريفين١٣ ابن عثيمين |
| 40.7 | 76.0 | 541 | re-OCR | اللقاءات الرمضانية - ابن عثيمين |
| 40.3 | 71.7 | 549 | re-OCR | فتاوى على الطريق - ابن عثيمين |
| 40.2 | 72.0 | 515 | re-OCR | لقاءات الباب المفتوح 01 ابن عثيمين |
| 39.8 | 73.1 | 369 | re-OCR | لقاءات الباب المفتوح 05 ابن عثيمين |
| 39.0 | 76.5 | 433 | re-OCR | اللقاءات الشهرية٣ - ابن عثيمين |
| 38.9 | 74.4 | 419 | re-OCR | دروس وفتاوى من الحرمين الشريفين١١ ابن عثيمين |
| 38.9 | 74.5 | 350 | re-OCR | دروس وفتاوى من الحرمين الشريفين١٧ ابن عثيمين |
| 38.7 | 76.3 | 615 | re-OCR | دروس وفتاوى من الحرمين الشريفين٧ ابن عثيمين |
| 38.4 | 73.1 | 320 | re-OCR | لقاءات الباب المفتوح 09 ابن عثيمين |
| 37.9 | 73.6 | 343 | re-OCR | لقاءات الباب المفتوح 02 ابن عثيمين |
| 37.6 | 75.0 | 452 | re-OCR | دروس وفتاوى من الحرمين الشريفين٥ ابن عثيمين |
| 37.1 | 73.7 | 431 | re-OCR | دروس وفتاوى من الحرمين الشريفين١٤ ابن عثيمين |
| 36.2 | 74.0 | 373 | re-OCR | لقاءات الباب المفتوح 04 ابن عثيمين |
| 36.0 | 74.3 | 481 | re-OCR | دروس وفتاوى من الحرمين الشريفين١٦ ابن عثيمين |
| 35.3 | 76.2 | 513 | re-OCR | فتاوى سؤال على الهاتف٢ ابن عثيمين |
| 35.2 | 73.7 | 412 | re-OCR | اللقاءات الشهرية٢ - ابن عثيمين |
| 35.2 | 74.4 | 378 | re-OCR | دروس وفتاوى من الحرمين الشريفين١٢ ابن عثيمين |
| 35.1 | 75.4 | 524 | re-OCR | دروس وفتاوى من الحرمين الشريفين١٨ ابن عثيمين |
| 34.4 | 73.8 | 282 | re-OCR | المناهي اللفظية - ابن عثيمين |
| 34.1 | 76.3 | 466 | re-OCR | دروس وفتاوى من الحرمين الشريفين٣ ابن عثيمين |
| 33.8 | 76.6 | 151 | re-OCR | لقاءات الحج - ابن عثيمين |
| 32.4 | 77.0 | 370 | re-OCR | اللقاءات الشهرية١ - ابن عثيمين |
| 30.4 | 78.7 | 322 | re-OCR | اللقاءات الشهرية٤ - ابن عثيمين |
| 27.7 | 77.0 | 422 | re-OCR | فتاوى الحج والعمرة٢ - ابن عثيمين |
| 27.6 | 78.4 | 445 | re-OCR | شرح العقيدة السفارينية ابن عثيمين |
| 26.9 | 76.5 | 409 | re-OCR | دروس وفتاوى من الحرمين الشريفين١٥ ابن عثيمين |
| 24.5 | 80.8 | 444 | re-OCR | فتاوى العقيدة١ - ابن عثيمين |
| 23.2 | 79.5 | 263 | re-OCR | فتاوى الطهارة والصلاة والجنائز٣ ابن عثيمين |
| 22.6 | 79.0 | 521 | re-OCR | فتاوى الزكاة والصيام - ابن عثيمين |
| 20.8 | 80.3 | 592 | re-OCR | فتاوى الطهارة والصلاة والجنائز١ ابن عثيمين |
| 20.8 | 80.7 | 534 | re-OCR | فتاوى الحج والعمرة١ - ابن عثيمين |
| 19.3 | 80.5 | 389 | re-OCR | فتاوى العقيدة٢ - ابن عثيمين |
| 18.8 | 81.6 | 549 | re-OCR | فتاوى الطهارة والصلاة والجنائز٢ ابن عثيمين |
| 15.3 | 82.4 | 496 | re-OCR | شرح اقتضاء الصراط المستقيم لابن تيمية ابن عثيمين |
| 11.1 | 89.9 | 9 | reload | رسالة في القضاء والقدر ابن عثيمين |
| 10.0 | 88.1 | 40 | reload | مختارات من اقتضاء الصراط المستقيم لابن تيمية ابن عثيمين |
| 9.0 | 85.5 | 221 | re-OCR | فتاوى نور على الدرب 06 - ابن عثيمين |
| 8.4 | 86.0 | 454 | re-OCR | فتاوى نور على الدرب 12 - ابن عثيمين |
| 7.9 | 88.2 | 216 | re-OCR | فتاوى نور على الدرب 03 - ابن عثيمين |
| 7.6 | 89.1 | 354 | re-OCR | فتاوى نور على الدرب 10 - ابن عثيمين |
| 6.1 | 84.9 | 280 | re-OCR | فتاوى نور على الدرب 08 - ابن عثيمين |
| 5.8 | 93.3 | 52 | re-OCR | إعلام المسافرين ببعض آداب وأحكام السفر |
| 5.4 | 88.7 | 479 | re-OCR | فتاوى نور على الدرب 01 - ابن عثيمين |
| 5.4 | 91.7 | 129 | re-OCR | مع رجال الحسبة توجيهات وفتاوى ابن عثيمين |
| 4.9 | 88.3 | 264 | — | فتاوى نور على الدرب 07 - ابن عثيمين |
| 4.7 | 90.0 | 429 | — | فتاوى نور على الدرب 11 - ابن عثيمين |
| 4.7 | 91.4 | 43 | — | الأدلة على بطلان الاشتراكية ابن عثيمين |
| 4.3 | 88.3 | 302 | — | فتاوى أركان الإسلام - ابن عثيمين |
| 4.0 | 87.9 | 420 | — | فتاوى نور على الدرب 02 - ابن عثيمين |
| 3.8 | 88.7 | 289 | — | فتاوى نور على الدرب 09 - ابن عثيمين |
| 2.2 | 90.4 | 455 | — | فتاوى نور على الدرب 04 - ابن عثيمين |
| 1.2 | 90.2 | 411 | — | فتاوى نور على الدرب 05 - ابن عثيمين |
| 0.0 | 91.4 | 9 | — | الإبداع في كمال الشرع وخطر الابتداع ابن عثيمين |
| 0.0 | 92.0 | 25 | — | التعليق على رسالة رفع الأساطين في حكم الاتصال بالسلاطين ابن عثيمين |
| 0.0 | 93.7 | 17 | — | أسماء الله وصفاته وموقف أهل السنة منها ابن عثيمين |
