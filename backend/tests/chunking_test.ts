import { assert, assertEquals } from "jsr:@std/assert@1";
import { chunkDocument } from "../functions/api/ai_search/chunking.ts";

/** A single ~10-token (~40 char) sentence, numbered so fixtures are readable
 *  in failure output and easy to reason about by index. */
function sentence(n: number): string {
  return `This is sentence number ${n} in the fixture text right now.`;
}

/** `count` sentences as one paragraph block (single blank-line-free run). */
function paragraph(count: number, startAt = 0): string {
  return Array.from({ length: count }, (_, i) => sentence(startAt + i)).join(" ");
}

function page(n: number, body: string): string {
  return `<!-- page:${n} -->\n\n${body}\n\n`;
}

Deno.test("a short single-page document becomes one chunk containing all its sentences", () => {
  const body = `${paragraph(2)}\n\n${paragraph(2, 2)}`;
  const doc = page(1, body);

  const chunks = chunkDocument(doc);

  assertEquals(chunks.length, 1);
  assertEquals(chunks[0].pageNumber, 1);
  assert(chunks[0].text.includes(sentence(0)));
  assert(chunks[0].text.includes(sentence(3)));
  assert(!chunks[0].text.includes("<!--"));
});

Deno.test("every chunk's text is built only from real document substrings, never a page marker", () => {
  // ~30 sentences (~300 tokens) across 3 paragraphs, comfortably forces
  // multiple chunks once packed near the ~700-token ceiling alongside more pages.
  const body = [paragraph(10, 0), paragraph(10, 10), paragraph(10, 20)].join("\n\n");
  const doc = page(1, body) + page(2, [paragraph(10, 30), paragraph(10, 40)].join("\n\n"));

  const chunks = chunkDocument(doc, { minTokens: 100, maxTokens: 180 });

  assert(chunks.length > 1, "fixture should force more than one chunk");
  for (const c of chunks) {
    assert(!c.text.includes("<!--"), "a chunk must never contain a page marker");
    // Every sentence quoted in the chunk really is a verbatim run of the
    // original document — just not necessarily one contiguous slice of it.
    for (const s of c.text.split(/\n\n+/)) {
      assert(doc.includes(s), `chunk fragment should be a literal substring of the document: "${s}"`);
    }
  }
});

Deno.test("consecutive chunks overlap by roughly the configured ratio", () => {
  const body = Array.from({ length: 6 }, (_, i) => paragraph(6, i * 6)).join("\n\n");
  const doc = page(1, body);

  const chunks = chunkDocument(doc, { minTokens: 60, maxTokens: 100, overlapRatio: 0.15 });

  assert(chunks.length >= 2, "fixture should force multiple chunks");
  for (let i = 1; i < chunks.length; i++) {
    // Overlap ⇒ the next chunk starts before the previous one ends, but
    // strictly after it started (forward progress, no infinite loop).
    assert(chunks[i].startOffset < chunks[i - 1].endOffset, `chunk ${i} should overlap chunk ${i - 1}`);
    assert(
      chunks[i].startOffset > chunks[i - 1].startOffset,
      `chunk ${i} must start after chunk ${i - 1} started`,
    );
  }
});

Deno.test("a chunk that straddles a page break cites the page with the majority of its text", () => {
  // Page 1 has one short trailing paragraph; page 2 has a long paragraph
  // right after it — a chunk packing both should attribute to page 2.
  const doc = page(1, paragraph(2, 0)) + page(2, paragraph(20, 2));

  const chunks = chunkDocument(doc, { minTokens: 150, maxTokens: 250 });

  const straddling = chunks.find((c) => c.text.includes(sentence(0)) && c.text.includes(sentence(3)));
  assert(straddling, "expected a chunk spanning both pages in this fixture");
  assertEquals(straddling.pageNumber, 2);
});

Deno.test("an oversized single paragraph is split at sentence boundaries, never mid-sentence", () => {
  const body = paragraph(40); // one giant paragraph, no blank lines inside it
  const doc = page(1, body);

  const chunks = chunkDocument(doc, { minTokens: 50, maxTokens: 100 });

  assert(chunks.length > 1);
  for (const c of chunks) {
    // Every chunk must end at a sentence terminator (or the document's end).
    const endsCleanly = /[.!?؟۔]$/.test(c.text.trimEnd()) || c.endOffset === doc.length;
    assert(endsCleanly, `chunk should not cut mid-sentence: "${c.text.slice(-30)}"`);
  }
});

Deno.test("chunks stay in document order", () => {
  const body = Array.from({ length: 8 }, (_, i) => paragraph(8, i * 8)).join("\n\n");
  const doc = page(1, body) + page(2, paragraph(8, 64));

  const chunks = chunkDocument(doc, { minTokens: 80, maxTokens: 140 });

  for (let i = 1; i < chunks.length; i++) {
    assert(chunks[i].startOffset > chunks[i - 1].startOffset);
  }
});

Deno.test("an empty document produces no chunks", () => {
  assertEquals(chunkDocument(""), []);
});
