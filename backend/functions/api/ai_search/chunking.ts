// Pure chunker for OCR'd book Markdown (docs/features/ai-search-m5.0-spec.md
// §Chunking). Input is one book's `fatwa.documents.original_text` — the full
// OCR'd Markdown with a `<!-- page:N -->` marker before each page's content
// (the OCR pipeline's established convention: markers always sit on their
// own line, blank-line-separated from surrounding text). No network, no
// Deno/Supabase globals — safe to unit test in isolation.
//
// Every chunk's start/end offsets index into the *original* document string
// (for audit/re-extraction), and `text` is built by joining the exact
// substrings of the blocks it contains — never reflowed/paraphrased, just
// stitched — so citation-verify's substring match against `fatwa.chunks.text`
// is checking the real source. A naive `document.slice(start, end)` would be
// wrong here: a chunk spanning a page break would sweep up the
// `<!-- page:N -->` marker (and anything else) sitting between its blocks.

export interface Chunk {
  text: string;
  startOffset: number;
  endOffset: number;
  /** The page most of this chunk's characters came from — a chunk that
   *  straddles a page break still cites correctly (§Chunking: "cite the
   *  page the majority of the chunk's text is on"). */
  pageNumber: number;
}

export interface ChunkOptions {
  minTokens?: number;
  maxTokens?: number;
  overlapRatio?: number;
}

const DEFAULT_MIN_TOKENS = 400;
const DEFAULT_MAX_TOKENS = 700;
const DEFAULT_OVERLAP_RATIO = 0.15;

const PAGE_MARKER_RE = /<!--\s*page:(\d+)\s*-->/g;
const BLANK_LINE_RE = /\n{2,}/g;
// Sentence terminators shared by Arabic and Latin punctuation conventions in
// this corpus (، is a comma, not a terminator — deliberately excluded).
const SENTENCE_BOUNDARY_RE = /(?<=[.!?؟۔])\s+/g;

/** ~4 chars/token is a standard rough estimate absent a real tokenizer
 *  (this edge function has none available) — good enough for chunk sizing,
 *  not for billing. */
function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4);
}

interface Block {
  text: string;
  start: number;
  end: number;
  page: number;
}

/** Splits `text` on blank-line boundaries into trimmed, offset-tracked
 *  blocks. `baseOffset` is where `text` begins in the *original* document —
 *  every returned block's start/end is absolute against that original. */
function splitIntoBlocks(text: string, baseOffset: number, page: number): Block[] {
  const blocks: Block[] = [];
  let lastEnd = 0;
  let match: RegExpExecArray | null;
  BLANK_LINE_RE.lastIndex = 0;
  const pushIfNonBlank = (raw: string, rawStart: number) => {
    const trimmed = raw.trim();
    if (trimmed.length === 0) return;
    const leadingWs = raw.length - raw.trimStart().length;
    const start = baseOffset + rawStart + leadingWs;
    blocks.push({ text: trimmed, start, end: start + trimmed.length, page });
  };
  while ((match = BLANK_LINE_RE.exec(text)) !== null) {
    pushIfNonBlank(text.slice(lastEnd, match.index), lastEnd);
    lastEnd = BLANK_LINE_RE.lastIndex;
  }
  pushIfNonBlank(text.slice(lastEnd), lastEnd);
  return blocks;
}

/** Splits a paragraph block into its individual sentences (still
 *  offset-tracked). Packing at sentence granularity — rather than only
 *  falling back to it for oversized paragraphs — keeps chunk boundaries and
 *  overlap slices from ever landing mid-sentence, and gives the overlap step
 *  room to work even when a single paragraph is a whole chunk on its own. */
function splitIntoSentences(block: Block): Block[] {
  const parts: Block[] = [];
  let lastEnd = 0;
  let match: RegExpExecArray | null;
  SENTENCE_BOUNDARY_RE.lastIndex = 0;
  const flush = (rawEnd: number) => {
    const raw = block.text.slice(lastEnd, rawEnd);
    const trimmed = raw.trim();
    if (trimmed.length === 0) return;
    const leadingWs = raw.length - raw.trimStart().length;
    const start = block.start + lastEnd + leadingWs;
    parts.push({ text: trimmed, start, end: start + trimmed.length, page: block.page });
  };
  while ((match = SENTENCE_BOUNDARY_RE.exec(block.text)) !== null) {
    flush(match.index);
    lastEnd = SENTENCE_BOUNDARY_RE.lastIndex;
  }
  flush(block.text.length);
  return parts.length > 0 ? parts : [block];
}

/** Parses `<!-- page:N -->` markers and returns each page's raw text as an
 *  absolute-offset block list (never crossing a page boundary, since markers
 *  are always block-level in this corpus's OCR output convention). */
function pageBlocks(document: string): Block[] {
  const markers: { page: number; contentStart: number }[] = [];
  let m: RegExpExecArray | null;
  PAGE_MARKER_RE.lastIndex = 0;
  while ((m = PAGE_MARKER_RE.exec(document)) !== null) {
    markers.push({ page: Number(m[1]), contentStart: PAGE_MARKER_RE.lastIndex });
  }
  const blocks: Block[] = [];
  for (let i = 0; i < markers.length; i++) {
    const { page, contentStart } = markers[i];
    const contentEnd = i + 1 < markers.length
      ? document.slice(0, markers[i + 1].contentStart).lastIndexOf("<!--")
      : document.length;
    const segment = document.slice(contentStart, contentEnd);
    blocks.push(...splitIntoBlocks(segment, contentStart, page));
  }
  return blocks;
}

function dominantPage(blocks: Block[]): number {
  const charsByPage = new Map<number, number>();
  for (const b of blocks) charsByPage.set(b.page, (charsByPage.get(b.page) ?? 0) + b.text.length);
  let best = blocks[0].page;
  let bestChars = -1;
  for (const [page, chars] of charsByPage) {
    if (chars > bestChars) {
      best = page;
      bestChars = chars;
    }
  }
  return best;
}

/** Chunks one book's full OCR'd Markdown into ~400–700 token passages with
 *  ~15% overlap, packing whole paragraph/sentence blocks so a chunk never
 *  splits mid-sentence, and tracking the page each chunk's majority text
 *  came from. */
export function chunkDocument(document: string, opts: ChunkOptions = {}): Chunk[] {
  const minTokens = opts.minTokens ?? DEFAULT_MIN_TOKENS;
  const maxTokens = opts.maxTokens ?? DEFAULT_MAX_TOKENS;
  const overlapRatio = opts.overlapRatio ?? DEFAULT_OVERLAP_RATIO;
  const overlapBudget = Math.round(maxTokens * overlapRatio);

  const rawBlocks = pageBlocks(document);
  const blocks = rawBlocks.flatMap((b) => splitIntoSentences(b));
  if (blocks.length === 0) return [];

  const chunks: Chunk[] = [];
  let i = 0;
  while (i < blocks.length) {
    let j = i;
    let tokens = 0;
    // Always take at least one block, even if it alone exceeds maxTokens
    // (already sentence-split above, so this is a rare, unavoidable case).
    while (j < blocks.length) {
      const nextTokens = tokens + estimateTokens(blocks[j].text);
      if (j > i && nextTokens > maxTokens && tokens >= minTokens) break;
      if (j > i && nextTokens > maxTokens) break;
      tokens = nextTokens;
      j++;
    }
    const included = blocks.slice(i, j);
    const first = included[0];
    const last = included[included.length - 1];
    chunks.push({
      text: included.map((b) => document.slice(b.start, b.end)).join("\n\n"),
      startOffset: first.start,
      endOffset: last.end,
      pageNumber: dominantPage(included),
    });

    if (j >= blocks.length) break;

    // Walk backward from j to find how many trailing blocks cover the
    // overlap budget, without regressing before i (guarantees progress).
    let k = j;
    let overlapTokens = 0;
    while (k > i + 1 && overlapTokens < overlapBudget) {
      k--;
      overlapTokens += estimateTokens(blocks[k].text);
    }
    i = k;
  }
  return chunks;
}
