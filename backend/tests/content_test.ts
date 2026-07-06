import { assertEquals } from "jsr:@std/assert@1";
import { route } from "../functions/api/router.ts";
import { InMemoryConfigRepo } from "./in_memory_repo.ts";
import { InMemoryIdentityRepo } from "./in_memory_identity_repo.ts";
import { InMemoryContentRepo } from "./in_memory_content_repo.ts";
import {
  InMemoryAdminAuthRepo,
  InMemoryAdminContentRepo,
  InMemoryAuditLogRepo,
} from "./in_memory_admin_repo.ts";
import { DevIdentityProviderVerifier } from "../functions/api/auth/provider_verify.ts";
import { InMemoryGamificationRepo } from "./in_memory_gamification_repo.ts";
import { InMemoryLeaderboardRepo } from "./in_memory_leaderboard_repo.ts";

const BASE = "https://x.supabase.co/functions/v1/api";

function deps() {
  return {
    repo: new InMemoryConfigRepo(),
    identity: new InMemoryIdentityRepo(),
    content: new InMemoryContentRepo(),
    adminContent: new InMemoryAdminContentRepo(),
    adminAuth: new InMemoryAdminAuthRepo(),
    auditLog: new InMemoryAuditLogRepo(),
    jwtSecret: "test-secret",
    verifier: new DevIdentityProviderVerifier(),
    gamification: new InMemoryGamificationRepo(),
    leaderboard: new InMemoryLeaderboardRepo(),
  };
}

function get(path: string, headers: HeadersInit = {}): Request {
  return new Request(`${BASE}${path}`, { headers });
}

Deno.test("GET /v1/content/azkar returns categories with nested items", async () => {
  const res = await route(get("/v1/content/azkar"), deps());
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.version, 3);
  assertEquals(body.categories[0].slug, "morning");
  assertEquals(body.categories[0].items[0].repeatCount, 100);
});

Deno.test("GET /v1/content/azkar honors since_version", async () => {
  const upToDate = await route(get("/v1/content/azkar?since_version=3"), deps());
  assertEquals(await upToDate.json(), { up_to_date: true });

  const stale = await route(get("/v1/content/azkar?since_version=1"), deps());
  const body = await stale.json();
  assertEquals(body.version, 3);
});

Deno.test("GET /v1/content/azkar rejects invalid since_version", async () => {
  const res = await route(get("/v1/content/azkar?since_version=abc"), deps());
  assertEquals(res.status, 400);
});

Deno.test("GET /v1/content/duas returns categories with nested duas", async () => {
  const res = await route(get("/v1/content/duas"), deps());
  const body = await res.json();
  assertEquals(body.categories[0].duas[0].title, "ربنا آتنا");
});

Deno.test("GET /v1/content/hadith-collections returns summaries without entries", async () => {
  const res = await route(get("/v1/content/hadith-collections"), deps());
  const body = await res.json();
  assertEquals(body.collections.length, 1);
  assertEquals(body.collections[0].slug, "nawawi40");
  assertEquals(body.collections[0].entryCount, 3);
  assertEquals("entries" in body.collections[0], false);
});

Deno.test("GET /v1/content/hadith-collections/{slug} returns full entries", async () => {
  const res = await route(get("/v1/content/hadith-collections/nawawi40"), deps());
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.entries[0].number, 1);
  assertEquals(body.entries[0].grading, "متفق عليه");
});

Deno.test("GET /v1/content/hadith-collections/{slug} 404s for unknown slug", async () => {
  const res = await route(get("/v1/content/hadith-collections/nonexistent"), deps());
  assertEquals(res.status, 404);
  assertEquals((await res.json()).error.code, "collection_not_found");
});

Deno.test("GET /v1/content/hadith-collections/{slug} honors since_version", async () => {
  const res = await route(get("/v1/content/hadith-collections/nawawi40?since_version=5"), deps());
  assertEquals(await res.json(), { up_to_date: true });
});

Deno.test("GET /v1/content/wird-templates returns templates", async () => {
  const res = await route(get("/v1/content/wird-templates"), deps());
  const body = await res.json();
  assertEquals(body.templates[0].type, "salawat");
  assertEquals(body.templates[0].defaultTarget, 100);
});
