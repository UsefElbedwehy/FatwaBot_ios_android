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
const OCCURRED = "2026-07-25T12:00:00Z";

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

function post(path: string, body: unknown, headers: HeadersInit = {}): Request {
  return new Request(`${BASE}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

async function signIn(d: ReturnType<typeof deps>) {
  return await (await route(post("/v1/auth/anonymous", { device: DEVICE }), d)).json();
}

async function authHeader(d: ReturnType<typeof deps>) {
  const user = await signIn(d);
  return { authorization: `Bearer ${user.access_token}` };
}

function screenView(clientEventId: string, params: Record<string, unknown> = { screen: "dua" }) {
  return {
    client_event_id: clientEventId,
    name: "screen_view",
    occurred_at: OCCURRED,
    platform: "ios",
    app_version: "0.1.0",
    params,
  };
}

async function submit(d: ReturnType<typeof deps>, auth: HeadersInit, events: unknown[]) {
  const res = await route(post("/v1/analytics/events", { events }, auth), d);
  return { status: res.status, body: await res.json() };
}

/** The stored user id is the JWT subject; recover it from /v1/me rather than guessing. */
async function userIdOf(d: ReturnType<typeof deps>, auth: HeadersInit): Promise<string> {
  const me = await (await route(new Request(`${BASE}/v1/me`, { headers: auth }), d)).json();
  return me.user_id;
}

Deno.test("analytics ingest accepts a batch and stores the coerced params", async () => {
  const d = deps();
  const auth = await authHeader(d);

  const { status, body } = await submit(d, auth, [
    screenView("evt-1"),
    // params values are coerced to strings; numbers/booleans are legal client input
    { ...screenView("evt-2"), params: { screen: "azkar", index: 3, first_open: true } },
    // platform/app_version/params are all optional
    { client_event_id: "evt-3", name: "app_open", occurred_at: OCCURRED },
  ]);

  assertEquals(status, 200);
  assertEquals(body, { accepted: 3, duplicates: 0, rejected: 0 });

  const stored = d.analytics.stored(await userIdOf(d, auth));
  assertEquals(stored.map((e) => e.name), ["screen_view", "screen_view", "app_open"]);
  assertEquals(stored[1].params, { screen: "azkar", index: "3", first_open: "true" });
  assertEquals(stored[2].platform, undefined);
});

Deno.test("analytics ingest is idempotent — resubmitting a client_event_id doesn't double count", async () => {
  const d = deps();
  const auth = await authHeader(d);

  const first = await submit(d, auth, [screenView("evt-1")]);
  assertEquals(first.body, { accepted: 1, duplicates: 0, rejected: 0 });

  // A retried flush after a dropped response: same ids, nothing new stored.
  const replay = await submit(d, auth, [screenView("evt-1"), screenView("evt-2")]);
  assertEquals(replay.body, { accepted: 1, duplicates: 1, rejected: 0 });
});

Deno.test("analytics ingest rejects a missing/empty/oversized events array with 400", async () => {
  const d = deps();
  const auth = await authHeader(d);

  const missing = await submit(d, auth, undefined as unknown as unknown[]);
  assertEquals(missing.status, 400);
  assertEquals(missing.body.error.code, "invalid_body");

  const empty = await submit(d, auth, []);
  assertEquals(empty.status, 400);
  assertEquals(empty.body.error.code, "invalid_body");

  const notAnArray = await route(post("/v1/analytics/events", { events: "screen_view" }, auth), d);
  assertEquals(notAnArray.status, 400);

  const oversized = await submit(
    d,
    auth,
    Array.from({ length: 101 }, (_, i) => screenView(`evt-${i}`)),
  );
  assertEquals(oversized.status, 400);
  assertEquals(oversized.body.error.code, "invalid_body");

  // exactly at the cap is fine
  const atCap = await submit(d, auth, Array.from({ length: 100 }, (_, i) => screenView(`cap-${i}`)));
  assertEquals(atCap.status, 200);
  assertEquals(atCap.body, { accepted: 100, duplicates: 0, rejected: 0 });
});

Deno.test("analytics ingest requires auth", async () => {
  const d = deps();
  const res = await route(post("/v1/analytics/events", { events: [screenView("evt-1")] }), d);
  assertEquals(res.status, 401);

  const badToken = await route(
    post("/v1/analytics/events", { events: [screenView("evt-1")] }, { authorization: "Bearer nope" }),
    d,
  );
  assertEquals(badToken.status, 401);
});

Deno.test("a single invalid event is counted in rejected without failing the batch", async () => {
  const d = deps();
  const auth = await authHeader(d);

  const invalid = [
    { ...screenView("bad-1"), client_event_id: "" }, // empty client_event_id
    { ...screenView("bad-2"), client_event_id: 42 }, // non-string client_event_id
    { ...screenView("bad-3"), name: "" }, // empty name
    { ...screenView("bad-4"), name: "x".repeat(65) }, // name over 64 chars
    { ...screenView("bad-5"), occurred_at: "not-a-date" }, // unparseable timestamp
    { ...screenView("bad-6"), occurred_at: 1690000000 }, // non-string timestamp
    { ...screenView("bad-7"), platform: "web" }, // platform outside ios/android
    { ...screenView("bad-8"), app_version: "v".repeat(33) }, // app_version over 32 chars
    { ...screenView("bad-9"), app_version: 1 }, // non-string app_version
    { ...screenView("bad-10"), params: "screen=dua" }, // params not an object
    { ...screenView("bad-11"), params: ["dua"] }, // params array
    // params with 11 keys — over the 10-key cap
    {
      ...screenView("bad-12"),
      params: Object.fromEntries(Array.from({ length: 11 }, (_, i) => [`k${i}`, "v"])),
    },
    null,
  ];

  const { status, body } = await submit(d, auth, [screenView("good-1"), ...invalid, screenView("good-2")]);
  assertEquals(status, 200);
  // the two good events still land; every bad one is only counted
  assertEquals(invalid.length, 13);
  assertEquals(body, { accepted: 2, duplicates: 0, rejected: 13 });

  const stored = d.analytics.stored(await userIdOf(d, auth));
  assertEquals(stored.map((e) => e.clientEventId), ["good-1", "good-2"]);
});

Deno.test("PRIVACY GUARD: events whose params carry a forbidden key are rejected, not stored", async () => {
  const d = deps();
  const auth = await authHeader(d);

  const forbidden = [
    "query",
    "q",
    "search",
    "search_query",
    "text",
    "body",
    "content",
    "lat",
    "latitude",
    "lng",
    "longitude",
    "location",
    "city",
    "coords",
    "name",
    "display_name",
    "email",
    "phone",
    "token",
    "push_token",
    "user_id",
  ];

  for (const key of forbidden) {
    const { status, body } = await submit(d, auth, [
      { ...screenView(`evt-${key}`), params: { screen: "dua", [key]: "sensitive" } },
    ]);
    assertEquals(status, 200, `forbidden key ${key} must not fail the request`);
    assertEquals(body, { accepted: 0, duplicates: 0, rejected: 1 }, `forbidden key ${key} must be rejected`);
  }

  // matching is case-insensitive on the exact key
  const cased = await submit(d, auth, [{ ...screenView("evt-cased"), params: { LaT: "24.7" } }]);
  assertEquals(cased.body, { accepted: 0, duplicates: 0, rejected: 1 });

  // one poisoned event doesn't take the clean ones down with it
  const mixed = await submit(d, auth, [
    screenView("clean-1"),
    { ...screenView("poisoned"), params: { query: "how do I pray" } },
    screenView("clean-2"),
  ]);
  assertEquals(mixed.body, { accepted: 2, duplicates: 0, rejected: 1 });

  // nothing sensitive ever reached storage
  const stored = d.analytics.stored(await userIdOf(d, auth));
  assertEquals(stored.map((e) => e.clientEventId), ["clean-1", "clean-2"]);
  assertEquals(
    stored.every((e) => Object.keys(e.params ?? {}).every((k) => !forbidden.includes(k.toLowerCase()))),
    true,
  );

  // a key that merely CONTAINS a forbidden word is fine — the match is exact
  const nearMiss = await submit(d, auth, [
    { ...screenView("near-miss"), params: { query_count: "2", latency_ms: "40" } },
  ]);
  assertEquals(nearMiss.body, { accepted: 1, duplicates: 0, rejected: 0 });
});

// Legitimate params are short stable keys, so an oversized value means a client
// is sending free text under an allowed key — the exact thing the guard exists to
// refuse. Truncating would silently persist 100 chars of a possible user query.
Deno.test("oversized param values reject the event rather than being truncated", async () => {
  const d = deps();
  const auth = await authHeader(d);

  const { body } = await submit(d, auth, [
    { ...screenView("evt-long"), params: { screen: "d".repeat(250) } },
  ]);
  assertEquals(body, { accepted: 0, duplicates: 0, rejected: 1 });

  assertEquals(d.analytics.stored(await userIdOf(d, auth)).length, 0);
});

Deno.test("a param value at exactly the limit is still accepted", async () => {
  const d = deps();
  const auth = await authHeader(d);

  const { body } = await submit(d, auth, [
    { ...screenView("evt-edge"), params: { screen: "d".repeat(100) } },
  ]);
  assertEquals(body, { accepted: 1, duplicates: 0, rejected: 0 });
});
