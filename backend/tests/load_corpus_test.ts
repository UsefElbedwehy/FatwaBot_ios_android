import { assertEquals, assertMatch, assertStringIncludes } from "jsr:@std/assert@1";
import {
  batchByTokenBudget,
  buildBookSql,
  buildScholarSql,
  type EmbeddedChunk,
  parseBookFile,
  vectorLiteral,
} from "../scripts/ai_ingest/load_corpus.ts";

const SAMPLE_BOOK = `<!-- source: العقيدة/شرح ثلاثة الأصول - ابن عثيمين.pdf -->

<!-- page:1 -->

[صفحة فارغة أو تجميلية]

<!-- page:2 -->

بسم الله الرحمن الرحيم. هذا نص تجريبي للصفحة الثانية.

<!-- page:5 -->

نص الصفحة الخامسة.
`;

Deno.test("parseBookFile reads the source header and total pages", () => {
  const book = parseBookFile(SAMPLE_BOOK);
  if (!book) throw new Error("expected a parsed book");
  assertEquals(book.relativePath, "العقيدة/شرح ثلاثة الأصول - ابن عثيمين.pdf");
  assertEquals(book.category, "العقيدة");
  assertEquals(book.title, "شرح ثلاثة الأصول - ابن عثيمين");
  assertEquals(book.totalPages, 5, "highest page marker, not the count of markers");
});

Deno.test("parseBookFile returns null without a source header", () => {
  assertEquals(parseBookFile("<!-- page:1 -->\n\nsome text"), null);
});

Deno.test("vectorLiteral formats a pgvector literal with fixed precision", () => {
  assertEquals(vectorLiteral([1, -0.5, 0.333333333]), "'[1.000000,-0.500000,0.333333]'::vector");
});

Deno.test("buildScholarSql is deterministic across calls", () => {
  const a = buildScholarSql();
  const b = buildScholarSql();
  assertEquals(a.id, b.id, "the same seed must always produce the same scholar id");
  assertMatch(a.sql, /on conflict \(id\) do update/);
});

function fakeChunk(overrides: Partial<EmbeddedChunk> = {}): EmbeddedChunk {
  return {
    id: "11111111-1111-4111-8111-111111111111",
    text: "نص تجريبي",
    startOffset: 0,
    endOffset: 10,
    pageNumber: 2,
    embedding: [0.1, 0.2, 0.3],
    ...overrides,
  };
}

Deno.test("buildBookSql upserts the source, document, and chunks, never sets license_status", () => {
  const book = parseBookFile(SAMPLE_BOOK)!;
  const sql = buildBookSql(book, [fakeChunk()], { scholarId: "22222222-2222-4222-8222-222222222222" });

  assertStringIncludes(sql, "insert into fatwa.sources");
  assertStringIncludes(sql, "insert into fatwa.documents");
  assertStringIncludes(sql, "insert into fatwa.chunks");
  assertStringIncludes(sql, "'[0.100000,0.200000,0.300000]'::vector");
  assertEquals(
    sql.includes("license_status"),
    false,
    "license_status is a copyright decision, never set by this importer",
  );
});

Deno.test("buildBookSql deletes chunks that no longer exist for the document", () => {
  const book = parseBookFile(SAMPLE_BOOK)!;
  const sql = buildBookSql(book, [fakeChunk()], { scholarId: "22222222-2222-4222-8222-222222222222" });

  assertStringIncludes(sql, "delete from fatwa.chunks where document_id =");
  assertStringIncludes(sql, "and id not in (");
});

Deno.test("buildBookSql handles a zero-chunk book without a malformed delete", () => {
  const book = parseBookFile(SAMPLE_BOOK)!;
  const sql = buildBookSql(book, [], { scholarId: "22222222-2222-4222-8222-222222222222" });

  assertStringIncludes(sql, "delete from fatwa.chunks where document_id = ");
  assertEquals(sql.includes("and id not in ()"), false, "an empty IN-list is invalid SQL");
});

Deno.test("buildBookSql is deterministic: same book + same chunks -> same ids", () => {
  const book = parseBookFile(SAMPLE_BOOK)!;
  const first = buildBookSql(book, [fakeChunk()], { scholarId: "22222222-2222-4222-8222-222222222222" });
  const second = buildBookSql(book, [fakeChunk()], { scholarId: "22222222-2222-4222-8222-222222222222" });
  assertEquals(first, second);
});

Deno.test("batchByTokenBudget splits a request that would exceed the token budget", () => {
  // 25 chunks of ~600 chars (~200 estimated tokens each) = ~5000 tokens —
  // this is the exact shape of the real failure: a whole book's chunks fit
  // an item-count cap of 64 but blow through Voyage's throttled-tier
  // 10K-tokens/minute limit when sent as one request.
  const texts = Array.from({ length: 25 }, () => "أ".repeat(600));
  const indices = texts.map((_, i) => i);

  const batches = batchByTokenBudget(indices, texts, 2000, 64);

  assertEquals(batches.length > 1, true, "must split into more than one request");
  for (const batch of batches) {
    const tokens = batch.reduce((sum, i) => sum + Math.ceil(texts[i].length / 3), 0);
    assertEquals(
      tokens <= 2000,
      true,
      `batch of ${batch.length} items estimated at ${tokens} tokens exceeds the budget`,
    );
  }
});

Deno.test("batchByTokenBudget respects the item-count cap even when tokens allow more", () => {
  const texts = Array.from({ length: 10 }, () => "short");
  const indices = texts.map((_, i) => i);

  const batches = batchByTokenBudget(indices, texts, 1_000_000, 3);

  assertEquals(batches, [[0, 1, 2], [3, 4, 5], [6, 7, 8], [9]]);
});

Deno.test("batchByTokenBudget always includes at least one item per batch, even an oversized one", () => {
  const texts = ["أ".repeat(100_000)];
  const batches = batchByTokenBudget([0], texts, 10, 64);
  assertEquals(batches, [[0]], "a single chunk larger than the budget must still go out, not be dropped");
});

Deno.test("buildBookSql batches chunk inserts across multiple statements", () => {
  const book = parseBookFile(SAMPLE_BOOK)!;
  const chunks = Array.from(
    { length: 5 },
    (_, i) => fakeChunk({ id: `${i}1111111-1111-4111-8111-111111111111` }),
  );
  const sql = buildBookSql(book, chunks, {
    scholarId: "22222222-2222-4222-8222-222222222222",
    rowsPerInsert: 2,
  });

  const insertCount = sql.split("insert into fatwa.chunks").length - 1;
  assertEquals(insertCount, 3, "5 rows at 2/insert should split into 3 statements");
});
