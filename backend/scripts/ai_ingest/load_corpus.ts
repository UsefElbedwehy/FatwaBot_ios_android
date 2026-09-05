// M5 corpus loader — assemble → chunk → embed → load (docs/features/
// ai-search-m5.0-spec.md, Build order step 3).
//
// Input: one Markdown file per book, already produced by self-transcription
// (a `<!-- source: <category>/<file>.pdf -->` header line, then the full
// OCR'd text with `<!-- page:N -->` markers — see ai_ingest/README.md).
// Output: an idempotent SQL file that upserts fatwa.scholars/sources/
// documents/chunks, applied the same way every other importer in this repo
// is (SQL editor or `psql -f`) — never a live DB connection from this script,
// matching hadith_import.ts/azkar_import.ts's established pattern.
//
// Real embeddings: calls VoyageEmbeddingProvider for real (needs
// VOYAGE_API_KEY), since that's the whole point of this script — chunking.ts/
// providers.ts were already unit-tested against the dev-stub. A local
// sha256(text)->embedding cache (--cache) makes re-runs (new/edited books)
// free for anything already embedded — this calls a paid API, so a crash or a
// second run should never re-spend on unchanged text.
//
// Sources are inserted with the schema's default license_status='pending' —
// this script never sets 'granted'. That flip is the copyright gate the spec
// calls out explicitly, and is not something an import script should decide.

import { chunkDocument } from "../../functions/api/ai_search/chunking.ts";
import { VoyageEmbeddingProvider } from "../../functions/api/ai_search/providers.ts";
import { chunk, deterministicUuid, generatedHeader, jsonbLiteral, sqlString } from "../import_common.ts";

const SCHOLAR_SEED = "fatwa-scholar:ibn-uthaymeen";
const SCHOLAR_NAME = { ar: "ابن عثيمين", en: "Ibn Uthaymeen" };
const SOURCE_HEADER_RE = /^<!--\s*source:\s*(.+?)\s*-->/;
const PAGE_MARKER_RE = /<!--\s*page:(\d+)\s*-->/g;

export interface ParsedBook {
  relativePath: string;
  category: string;
  title: string;
  originalText: string;
  totalPages: number;
}

/** Parses one transcribed book file. Returns `null` if it has no
 *  `<!-- source: ... -->` header — a file that isn't ready to ingest yet,
 *  skipped rather than treated as an error (the corpus is ingested
 *  incrementally as books finish transcription). */
export function parseBookFile(fileContents: string): ParsedBook | null {
  const firstLine = (fileContents.split("\n", 1)[0] ?? "").trim();
  const match = SOURCE_HEADER_RE.exec(firstLine);
  if (!match) return null;
  const relativePath = match[1];
  const segments = relativePath.split("/");
  const filename = segments[segments.length - 1];
  const category = segments.length > 1 ? segments.slice(0, -1).join("/").trim() : "";
  const title = filename.replace(/\.pdf$/i, "").replace(/_/g, " ").trim();
  const pageNumbers = [...fileContents.matchAll(PAGE_MARKER_RE)].map((m) => Number(m[1]));
  const totalPages = pageNumbers.length > 0 ? Math.max(...pageNumbers) : 0;
  return { relativePath, category, title, originalText: fileContents, totalPages };
}

export interface EmbeddedChunk {
  id: string;
  text: string;
  startOffset: number;
  endOffset: number;
  pageNumber: number;
  embedding: number[];
}

/** A pgvector literal — fixed precision keeps the generated SQL file a sane
 *  size across a whole corpus without meaningfully affecting cosine distance. */
export function vectorLiteral(embedding: number[]): string {
  return `'[${embedding.map((n) => n.toFixed(6)).join(",")}]'::vector`;
}

export function buildScholarSql(): { id: string; sql: string } {
  const id = deterministicUuid(SCHOLAR_SEED);
  const sql = `insert into fatwa.scholars (id, name_translations)\n` +
    `values (${sqlString(id)}::uuid, ${jsonbLiteral(SCHOLAR_NAME)})\n` +
    `on conflict (id) do update set name_translations = excluded.name_translations;\n`;
  return { id, sql };
}

/** One book's insert/upsert SQL: source, document, and every chunk — plus a
 *  cleanup delete for any chunk id that no longer exists (a book re-chunked
 *  after an OCR correction can produce fewer chunks than a prior run). Row
 *  ids are deterministic from (book path, chunk index), so re-running this
 *  script for the same book updates in place instead of duplicating. */
export function buildBookSql(
  book: ParsedBook,
  chunks: EmbeddedChunk[],
  deps: { scholarId: string; rowsPerInsert?: number },
): string {
  const sourceId = deterministicUuid(`fatwa-source:${book.relativePath}`);
  const documentId = deterministicUuid(`fatwa-document:${book.relativePath}`);
  const rowsPerInsert = deps.rowsPerInsert ?? 100;
  const lines: string[] = [];

  lines.push(
    `insert into fatwa.sources (id, scholar_id, kind, origin_path, title, category, total_pages)`,
    `values (${sqlString(sourceId)}::uuid, ${sqlString(deps.scholarId)}::uuid, 'book', ` +
      `${sqlString(book.relativePath)}, ${sqlString(book.title)}, ${
        sqlString(book.category)
      }, ${book.totalPages})`,
    `on conflict (id) do update set title = excluded.title, category = excluded.category, ` +
      `total_pages = excluded.total_pages, ingested_at = now();`,
    "",
  );

  lines.push(
    `insert into fatwa.documents (id, source_id, original_text)`,
    `values (${sqlString(documentId)}::uuid, ${sqlString(sourceId)}::uuid, ${sqlString(book.originalText)})`,
    `on conflict (id) do update set original_text = excluded.original_text;`,
    "",
  );

  for (const batch of chunk(chunks, rowsPerInsert)) {
    const rows = batch.map((c) =>
      `  (${sqlString(c.id)}::uuid, ${sqlString(documentId)}::uuid, ${sqlString(c.text)}, ` +
      `${c.startOffset}, ${c.endOffset}, ${c.pageNumber}, ${vectorLiteral(c.embedding)})`
    );
    lines.push(
      `insert into fatwa.chunks (id, document_id, text, start_offset, end_offset, page_number, embedding)`,
      `values\n${rows.join(",\n")}`,
      `on conflict (id) do update set text = excluded.text, start_offset = excluded.start_offset, ` +
        `end_offset = excluded.end_offset, page_number = excluded.page_number, embedding = excluded.embedding;`,
      "",
    );
  }

  const currentIds = chunks.map((c) => `${sqlString(c.id)}::uuid`);
  lines.push(
    `delete from fatwa.chunks where document_id = ${sqlString(documentId)}::uuid` +
      (currentIds.length > 0 ? ` and id not in (${currentIds.join(", ")});` : ";"),
    "",
  );

  return lines.join("\n");
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function loadCache(path: string): Promise<Map<string, number[]>> {
  try {
    const raw = await Deno.readTextFile(path);
    return new Map(Object.entries(JSON.parse(raw) as Record<string, number[]>));
  } catch {
    return new Map();
  }
}

async function saveCache(path: string, cache: Map<string, number[]>): Promise<void> {
  await Deno.writeTextFile(path, JSON.stringify(Object.fromEntries(cache)));
}

/** Deliberately more conservative than chunking.ts's chars/4 (English-shaped)
 *  estimate — Arabic script tends to tokenize *less* efficiently per
 *  character than that heuristic assumes, and underestimating here is what
 *  caused the very bug this function exists to prevent (see
 *  `batchByTokenBudget`'s doc comment). Rough and safe beats precise and wrong. */
function estimateTokens(text: string): number {
  return Math.ceil(text.length / 3);
}

/** Groups `indices` into request-sized batches bounded by BOTH an item count
 *  and an estimated token budget.
 *
 *  Voyage's throttled tier (no payment method on file) caps requests at
 *  10K tokens/minute — a book's chunks batched purely by count (the original
 *  version of this function) could put ~13K+ estimated tokens in one
 *  request, which then 429s on every retry forever, since retrying resends
 *  the exact same oversized request. Only the token-aware grouping actually
 *  fixes that; the retry/backoff in VoyageEmbeddingProvider only helps once
 *  each individual request already fits the budget. */
export function batchByTokenBudget(
  indices: number[],
  texts: string[],
  maxTokensPerBatch: number,
  maxItemsPerBatch: number,
): number[][] {
  const batches: number[][] = [];
  let current: number[] = [];
  let currentTokens = 0;
  for (const idx of indices) {
    const tokens = estimateTokens(texts[idx]);
    if (
      current.length > 0 && (currentTokens + tokens > maxTokensPerBatch || current.length >= maxItemsPerBatch)
    ) {
      batches.push(current);
      current = [];
      currentTokens = 0;
    }
    current.push(idx);
    currentTokens += tokens;
  }
  if (current.length > 0) batches.push(current);
  return batches;
}

/** Embeds `texts`, reusing `cache` for anything already embedded. Only the
 *  cache misses are sent to Voyage, batched to fit both limits. */
async function embedWithCache(
  provider: VoyageEmbeddingProvider,
  texts: string[],
  cache: Map<string, number[]>,
  limits: { maxItemsPerBatch: number; maxTokensPerBatch: number },
): Promise<number[][]> {
  const hashes = await Promise.all(texts.map(sha256Hex));
  const results: (number[] | undefined)[] = hashes.map((h) => cache.get(h));
  const missing = results.map((r, i) => (r === undefined ? i : -1)).filter((i) => i >= 0);

  for (
    const batch of batchByTokenBudget(missing, texts, limits.maxTokensPerBatch, limits.maxItemsPerBatch)
  ) {
    const embeddings = await provider.embed(batch.map((i) => texts[i]));
    batch.forEach((idx, j) => {
      results[idx] = embeddings[j];
      cache.set(hashes[idx], embeddings[j]);
    });
  }
  if (missing.length > 0) {
    console.error(
      `    embedded ${missing.length}/${texts.length} chunks (${texts.length - missing.length} cached)`,
    );
  } else {
    console.error(`    all ${texts.length} chunks already cached`);
  }
  return results as number[][];
}

interface CliArgs {
  dir: string;
  out: string;
  cache: string;
  maxItemsPerBatch: number;
  maxTokensPerBatch: number;
  requestsPerMinute: number;
}

function parseArgs(args: string[]): CliArgs {
  const map = new Map<string, string>();
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith("--")) {
      map.set(args[i].slice(2), args[i + 1]);
      i++;
    }
  }
  return {
    // Relative to backend/ — this script is meant to be run from there, like
    // every other importer (hadith_import.ts etc.).
    dir: map.get("dir") ?? "scripts/ai_ingest/pilot_output/markdown",
    out: map.get("out") ?? "supabase/imports/fatwa_corpus.sql",
    cache: map.get("cache") ?? "scripts/ai_ingest/.embedding_cache.json",
    maxItemsPerBatch: Number(map.get("batch-size") ?? "64"),
    // Paired with the default requestsPerMinute below: 2 req/min * 4000 =
    // 8000 tokens/min, safely under Voyage's throttled-tier 10K/min cap with
    // margin for estimateTokens() being a rough heuristic, not a real
    // tokenizer count.
    maxTokensPerBatch: Number(map.get("max-tokens-per-batch") ?? "4000"),
    // Below Voyage's stated 3/min throttled-tier limit — proactive pacing so
    // a burst of small books (one request each) doesn't 429 itself into a
    // corner the way an unpaced run did on this corpus's book #7.
    requestsPerMinute: Number(map.get("requests-per-minute") ?? "2"),
  };
}

if (import.meta.main) {
  const args = parseArgs(Deno.args);
  const apiKey = Deno.env.get("VOYAGE_API_KEY");
  if (!apiKey) {
    console.error(
      "Usage: VOYAGE_API_KEY=... deno run --allow-read --allow-write --allow-net --allow-env " +
        "scripts/ai_ingest/load_corpus.ts [--dir <markdown-dir>] [--out <file.sql>] [--cache <file.json>] " +
        "[--batch-size N] [--max-tokens-per-batch N] [--requests-per-minute N]",
    );
    Deno.exit(1);
  }

  const provider = new VoyageEmbeddingProvider(apiKey, { requestsPerMinute: args.requestsPerMinute });
  const cache = await loadCache(args.cache);
  const scholar = buildScholarSql();
  const outParts: string[] = [
    generatedHeader("fatwa corpus: scholars/sources/documents/chunks, real Voyage embeddings"),
    scholar.sql,
  ];

  const entries = [...Deno.readDirSync(args.dir)]
    .filter((e) => e.isFile && e.name.endsWith(".md"))
    .sort((a, b) => a.name.localeCompare(b.name));
  console.error(`Found ${entries.length} transcribed book(s) in ${args.dir}`);
  console.error(
    `Pacing Voyage requests to ${args.requestsPerMinute}/min — expect this to take a while on the throttled tier.`,
  );

  let totalChunks = 0;
  let skipped = 0;
  for (const [index, entry] of entries.entries()) {
    const contents = await Deno.readTextFile(`${args.dir}/${entry.name}`);
    const book = parseBookFile(contents);
    if (!book) {
      console.error(`  [${index + 1}/${entries.length}] skip ${entry.name}: no source header`);
      skipped++;
      continue;
    }
    const rawChunks = chunkDocument(book.originalText);
    if (rawChunks.length === 0) {
      console.error(`  [${index + 1}/${entries.length}] skip ${book.relativePath}: zero chunks`);
      skipped++;
      continue;
    }
    console.error(
      `[${
        index + 1
      }/${entries.length}] ${book.relativePath} — ${rawChunks.length} chunks, ${book.totalPages} pages`,
    );
    const embeddings = await embedWithCache(provider, rawChunks.map((c) => c.text), cache, {
      maxItemsPerBatch: args.maxItemsPerBatch,
      maxTokensPerBatch: args.maxTokensPerBatch,
    });
    const embeddedChunks: EmbeddedChunk[] = rawChunks.map((c, i) => ({
      id: deterministicUuid(`fatwa-chunk:${book.relativePath}:${i}`),
      text: c.text,
      startOffset: c.startOffset,
      endOffset: c.endOffset,
      pageNumber: c.pageNumber,
      embedding: embeddings[i],
    }));
    outParts.push(buildBookSql(book, embeddedChunks, { scholarId: scholar.id }));
    totalChunks += embeddedChunks.length;
    // Saved after every book, not just at the end — a crash or rate-limit
    // partway through must not lose already-paid-for embeddings.
    await saveCache(args.cache, cache);
  }

  await Deno.mkdir(new URL(".", `file://${Deno.cwd()}/${args.out}`).pathname, { recursive: true }).catch(
    () => {},
  );
  // Bump the corpus revision in the same script that inserts the chunks, so
  // applying an ingest invalidates every cached answer generated against the
  // previous corpus (0046_answer_cache.sql). Without this a question refused
  // before a book was ingested would keep serving that refusal from cache,
  // and the new book would look like it had never been loaded.
  outParts.push(
    "\n-- Invalidate cached answers: they were generated against the previous corpus.\n" +
      "update fatwa.corpus_state set generation = generation + 1, updated_at = now();\n",
  );
  await Deno.writeTextFile(args.out, outParts.join("\n"));
  console.error(
    `\nWrote ${entries.length - skipped} book(s) (${skipped} skipped), ${totalChunks} chunks → ${args.out}`,
  );
  console.error(`Apply via the Supabase SQL editor or: psql "$DATABASE_URL" -f ${args.out}`);
  console.error(
    `Every source lands with license_status='pending' — flip to 'granted' only after the copyright decision.`,
  );
}
