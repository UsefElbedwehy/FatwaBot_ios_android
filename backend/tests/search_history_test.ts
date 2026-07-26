import { assertEquals } from "jsr:@std/assert@1";
import { route } from "../functions/api/router.ts";
import { InMemoryConfigRepo } from "./in_memory_repo.ts";
import { InMemoryIdentityRepo } from "./in_memory_identity_repo.ts";
import { InMemoryContentRepo } from "./in_memory_content_repo.ts";
import {
  InMemoryAdminAuthRepo,
  InMemoryAdminContentRepo,
  InMemoryAdminUsersRepo,
  InMemoryAuditLogRepo,
} from "./in_memory_admin_repo.ts";
import { InMemoryAdminStringsRepo } from "./in_memory_admin_strings_repo.ts";
import { DevIdentityProviderVerifier } from "../functions/api/auth/provider_verify.ts";
import { InMemoryGamificationRepo } from "./in_memory_gamification_repo.ts";
import { InMemoryAnalyticsRepo } from "./in_memory_analytics_repo.ts";
import { InMemoryLeaderboardRepo } from "./in_memory_leaderboard_repo.ts";
import { InMemorySearchHistoryRepo } from "./in_memory_search_repo.ts";
import { InMemoryDeliveryLogRepo, InMemoryNotificationPrefsRepo } from "./in_memory_notification_repo.ts";

const BASE = "https://x.supabase.co/functions/v1/api";
const SECRET = "test-secret";
const DEVICE = { platform: "ios", app_version: "1.0.0", locale: "ar", timezone: "Asia/Riyadh" };

function deps() {
  return {
    repo: new InMemoryConfigRepo(),
    identity: new InMemoryIdentityRepo(),
    content: new InMemoryContentRepo(),
    adminContent: new InMemoryAdminContentRepo(),
    adminUsers: new InMemoryAdminUsersRepo(),
    adminAuth: new InMemoryAdminAuthRepo(),
    adminStrings: new InMemoryAdminStringsRepo(),
    auditLog: new InMemoryAuditLogRepo(),
    jwtSecret: SECRET,
    verifier: new DevIdentityProviderVerifier(),
    gamification: new InMemoryGamificationRepo(),
    analytics: new InMemoryAnalyticsRepo(),
    leaderboard: new InMemoryLeaderboardRepo(),
    searchHistory: new InMemorySearchHistoryRepo(),
    notificationPrefs: new InMemoryNotificationPrefsRepo(),
    deliveryLog: new InMemoryDeliveryLogRepo(),
  };
}

function post(path: string, body?: unknown, headers: HeadersInit = {}): Request {
  return new Request(`${BASE}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
}

function del(path: string, headers: HeadersInit = {}): Request {
  return new Request(`${BASE}${path}`, { method: "DELETE", headers });
}

async function signIn(d: ReturnType<typeof deps>) {
  return await (await route(post("/v1/auth/anonymous", { device: DEVICE }), d)).json();
}

Deno.test("recording a search entry requires a known source and non-empty query", async () => {
  const d = deps();
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  const badSource = await route(post("/v1/search-history", { source: "nope", query_text: "x" }, auth), d);
  assertEquals(badSource.status, 400);

  const emptyQuery = await route(post("/v1/search-history", { source: "azkar", query_text: "" }, auth), d);
  assertEquals(emptyQuery.status, 400);

  const ok = await route(
    post("/v1/search-history", { source: "azkar", query_text: "أذكار الصباح" }, auth),
    d,
  );
  assertEquals(ok.status, 201);
  const body = await ok.json();
  assertEquals(body.source, "azkar");
  assertEquals(body.query_text, "أذكار الصباح");
});

Deno.test("listing returns most-recent-first, filterable by source", async () => {
  const d = deps();
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  await route(post("/v1/search-history", { source: "azkar", query_text: "one" }, auth), d);
  await route(post("/v1/search-history", { source: "dua", query_text: "two" }, auth), d);
  await route(post("/v1/search-history", { source: "azkar", query_text: "three" }, auth), d);

  const all = await (await route(new Request(`${BASE}/v1/search-history`, { headers: auth }), d)).json();
  assertEquals(all.entries.map((e: { query_text: string }) => e.query_text), ["three", "two", "one"]);

  const azkarOnly = await (
    await route(new Request(`${BASE}/v1/search-history?source=azkar`, { headers: auth }), d)
  ).json();
  assertEquals(azkarOnly.entries.map((e: { query_text: string }) => e.query_text), ["three", "one"]);
});

Deno.test("delete one entry, then delete all — scoped to the authenticated user only", async () => {
  const d = deps();
  const alice = await signIn(d);
  const bob = await signIn(d);
  const aliceAuth = { authorization: `Bearer ${alice.access_token}` };
  const bobAuth = { authorization: `Bearer ${bob.access_token}` };

  const created = await (
    await route(post("/v1/search-history", { source: "azkar", query_text: "mine" }, aliceAuth), d)
  ).json();

  const bobDeleteAttempt = await route(del(`/v1/search-history/${created.id}`, bobAuth), d);
  assertEquals(bobDeleteAttempt.status, 404); // Bob can't delete Alice's entry

  const aliceDelete = await route(del(`/v1/search-history/${created.id}`, aliceAuth), d);
  assertEquals((await aliceDelete.json()).deleted, true);

  await route(post("/v1/search-history", { source: "dua", query_text: "another" }, aliceAuth), d);
  const clearAll = await route(del("/v1/search-history", aliceAuth), d);
  assertEquals((await clearAll.json()).cleared, true);
  const afterClear = await (await route(new Request(`${BASE}/v1/search-history`, { headers: aliceAuth }), d))
    .json();
  assertEquals(afterClear.entries, []);
});

Deno.test("search history routes require auth", async () => {
  const d = deps();
  assertEquals((await route(new Request(`${BASE}/v1/search-history`), d)).status, 401);
  assertEquals(
    (await route(post("/v1/search-history", { source: "azkar", query_text: "x" }), d)).status,
    401,
  );
});
