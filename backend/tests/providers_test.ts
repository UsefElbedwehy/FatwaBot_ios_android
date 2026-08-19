import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import {
  ClaudeAnswerProvider,
  DevStubAnswerProvider,
  DevStubEmbeddingProvider,
  VoyageEmbeddingProvider,
} from "../functions/api/ai_search/providers.ts";
import type { RetrievedChunk } from "../functions/api/fatwa_types.ts";

function chunk(over: Partial<RetrievedChunk> = {}): RetrievedChunk {
  return {
    chunkId: "chunk-1",
    documentId: "doc-1",
    sourceId: "source-1",
    scholarId: "scholar-1",
    text: "الوسط في الدين: أن لا يغلو الإنسان فيه ولا يقصر.",
    pageNumber: 25,
    videoTimestamp: null,
    sourceTitle: "فتاوى أركان الإسلام",
    sourceCategory: "الفتاوى واللقاءات",
    scholarName: { ar: "ابن عثيمين", en: "Ibn Uthaymeen" },
    score: 0.9,
    ...over,
  };
}

// --- DevStubEmbeddingProvider ---

Deno.test("DevStubEmbeddingProvider is deterministic and dimension-correct", async () => {
  const provider = new DevStubEmbeddingProvider(64);
  const [a] = await provider.embed(["hello"]);
  const [b] = await provider.embed(["hello"]);
  const [c] = await provider.embed(["different text"]);

  assertEquals(a.length, 64);
  assertEquals(a, b, "same input must produce the same vector");
  assertNotEquals(a, c, "different input must produce a different vector");
  assert(a.every((v) => v >= -1 && v <= 1));
});

// --- DevStubAnswerProvider ---

Deno.test("DevStubAnswerProvider refuses on empty retrieval", async () => {
  const provider = new DevStubAnswerProvider();
  const result = await provider.answer("سؤال ما", "general", [], "ar");
  assertEquals(result.refused, true);
  assertEquals(result.citations.length, 0);
});

Deno.test("DevStubAnswerProvider quotes the top chunk verbatim", async () => {
  const provider = new DevStubAnswerProvider();
  const c = chunk();
  const result = await provider.answer("ما معنى الوسط؟", "fatwa", [c], "ar");
  assertEquals(result.refused, false);
  assertEquals(result.citations.length, 1);
  assertEquals(result.citations[0].chunkId, c.chunkId);
  assertEquals(result.citations[0].quotedText, c.text);
  assert(result.answer.includes(c.text), "answer should embed the exact chunk text");
});

// --- VoyageEmbeddingProvider ---

Deno.test("VoyageEmbeddingProvider posts the right request and orders results by index", async () => {
  let capturedUrl = "";
  let capturedBody: unknown;
  const fakeFetch = ((url: string | URL | Request, init?: RequestInit) => {
    capturedUrl = String(url);
    capturedBody = JSON.parse(init!.body as string);
    // Return out of order to verify the provider re-sorts by index.
    return Promise.resolve(
      new Response(
        JSON.stringify({
          data: [
            { embedding: [0.2], index: 1 },
            { embedding: [0.1], index: 0 },
          ],
        }),
        { status: 200 },
      ),
    );
  }) as typeof fetch;

  const provider = new VoyageEmbeddingProvider("test-key", { fetch: fakeFetch });
  const result = await provider.embed(["first", "second"]);

  assertEquals(capturedUrl, "https://api.voyageai.com/v1/embeddings");
  assertEquals((capturedBody as { model: string }).model, "voyage-4");
  assertEquals((capturedBody as { input: string[] }).input, ["first", "second"]);
  assertEquals(result, [[0.1], [0.2]]);
});

Deno.test("VoyageEmbeddingProvider throws on a non-ok response", async () => {
  const fakeFetch = (() => Promise.resolve(new Response("bad key", { status: 401 }))) as typeof fetch;
  const provider = new VoyageEmbeddingProvider("bad-key", { fetch: fakeFetch });
  let threw = false;
  try {
    await provider.embed(["x"]);
  } catch {
    threw = true;
  }
  assert(threw);
});

// --- ClaudeAnswerProvider ---

/** Minimal fake standing in for the Anthropic SDK client — only the surface
 *  ClaudeAnswerProvider actually calls. */
function fakeAnthropicClient(
  handler: (params: Record<string, unknown>) => {
    stop_reason: string;
    content: { type: string; text?: string }[];
  },
) {
  const calls: Record<string, unknown>[] = [];
  return {
    calls,
    client: {
      messages: {
        // deno-lint-ignore require-await
        create: async (params: Record<string, unknown>) => {
          calls.push(params);
          return handler(params);
        },
      },
    },
  };
}

Deno.test("ClaudeAnswerProvider refuses without calling the model on empty retrieval", async () => {
  const { calls, client } = fakeAnthropicClient(() => {
    throw new Error("should not be called");
  });
  // deno-lint-ignore no-explicit-any
  const provider = new ClaudeAnswerProvider("key", { client: client as any });
  const result = await provider.answer("سؤال", "general", [], "ar");
  assertEquals(result.refused, true);
  assertEquals(calls.length, 0);
});

Deno.test("ClaudeAnswerProvider parses a structured JSON response and stamps the model id", async () => {
  const { calls, client } = fakeAnthropicClient((params) => {
    assertEquals(params.model, "claude-haiku-4-5");
    assertEquals(
      (params.output_config as { format: { type: string } }).format.type,
      "json_schema",
    );
    return {
      stop_reason: "end_turn",
      content: [{
        type: "text",
        text: JSON.stringify({
          answer: "الوسط في الدين أن لا يغلو الإنسان فيه.",
          refused: false,
          citations: [{
            chunkId: "chunk-1",
            scholar: "ابن عثيمين",
            sourceTitle: "فتاوى أركان الإسلام",
            pageNumber: 25,
            quotedText: "الوسط في الدين: أن لا يغلو الإنسان فيه ولا يقصر.",
          }],
        }),
      }],
    };
  });
  // deno-lint-ignore no-explicit-any
  const provider = new ClaudeAnswerProvider("key", { client: client as any });
  const result = await provider.answer("ما معنى الوسط؟", "fatwa", [chunk()], "ar");

  assertEquals(calls.length, 1);
  assertEquals(result.refused, false);
  assertEquals(result.model, "claude-haiku-4-5");
  assertEquals(result.citations[0].chunkId, "chunk-1");
});

Deno.test("ClaudeAnswerProvider treats a safety refusal as a refused answer", async () => {
  const { client } = fakeAnthropicClient(() => ({
    stop_reason: "refusal",
    content: [],
  }));
  // deno-lint-ignore no-explicit-any
  const provider = new ClaudeAnswerProvider("key", { client: client as any });
  const result = await provider.answer("سؤال", "general", [chunk()], "ar");
  assertEquals(result.refused, true);
  assertEquals(result.citations.length, 0);
});

Deno.test("ClaudeAnswerProvider honors a per-instance model override", async () => {
  const { calls, client } = fakeAnthropicClient(() => ({
    stop_reason: "end_turn",
    content: [{
      type: "text",
      text: JSON.stringify({ answer: "x", refused: false, citations: [] }),
    }],
  }));
  const provider = new ClaudeAnswerProvider("key", {
    model: "claude-sonnet-5",
    // deno-lint-ignore no-explicit-any
    client: client as any,
  });
  await provider.answer("سؤال", "general", [chunk()], "ar");
  assertEquals(calls[0].model, "claude-sonnet-5");
});
