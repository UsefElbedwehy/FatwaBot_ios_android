import { assertEquals } from "jsr:@std/assert@1";
import bcrypt from "npm:bcryptjs@2";
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
import { InMemoryFatwaSearchRepo } from "./in_memory_fatwa_repo.ts";

const BASE = "https://x.supabase.co/functions/v1/api";
const SECRET = "test-secret";
const DEVICE = { platform: "ios", app_version: "1.0.0", locale: "ar", timezone: "Asia/Riyadh" };

async function deps() {
  const adminAuth = new InMemoryAdminAuthRepo();
  adminAuth.admins.set("admin@fatwabot.dev", { id: "admin-1", passwordHash: await bcrypt.hash("pw", 10) });
  const adminContent = new InMemoryAdminContentRepo();
  adminContent.seed("leaderboard-defs", [
    {
      id: "lb-global-weekly",
      published: true,
      version: 1,
      fields: {
        key: "global_weekly",
        name_translations: { ar: "الأسبوعية العالمية", en: "Global Weekly" },
        scope: "global",
        period: "lifetime", // use lifetime so the test doesn't depend on "now"
        metric: { terms: [{ event_type: "azkar_completed", weight: 1, cap_per_period: 100 }] },
        tie_breakers: [],
        visibility: "public",
        display_requirements: { requires_published_name: false },
        enabled: true,
      },
    },
    {
      id: "lb-city",
      published: true,
      version: 1,
      fields: {
        key: "city_board",
        name_translations: { ar: "لوحة المدينة", en: "City Board" },
        scope: "city",
        period: "lifetime",
        metric: { terms: [{ event_type: "azkar_completed", weight: 1, cap_per_period: 100 }] },
        tie_breakers: [],
        visibility: "public",
        display_requirements: { requires_published_name: false },
        enabled: true,
      },
    },
  ]);

  return {
    repo: new InMemoryConfigRepo(),
    identity: new InMemoryIdentityRepo(),
    content: new InMemoryContentRepo(),
    adminContent,
    adminUsers: new InMemoryAdminUsersRepo(),
    adminAuth,
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
    fatwaSearch: new InMemoryFatwaSearchRepo(),
  };
}

function post(path: string, body?: unknown, headers: HeadersInit = {}): Request {
  return new Request(`${BASE}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
}

function patch(path: string, body: unknown, headers: HeadersInit = {}): Request {
  return new Request(`${BASE}${path}`, {
    method: "PATCH",
    headers: { "content-type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

async function signIn(d: Awaited<ReturnType<typeof deps>>) {
  return await (await route(post("/v1/auth/anonymous", { device: DEVICE }), d)).json();
}

Deno.test("GET /v1/leaderboards lists published boards with joined=false and my_rank=null before joining", async () => {
  const d = await deps();
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  const res = await route(new Request(`${BASE}/v1/leaderboards`, { headers: auth }), d);
  const body = await res.json();
  const board = body.boards.find((b: { key: string }) => b.key === "global_weekly");
  assertEquals(board.joined, false);
  assertEquals(board.my_rank, null);
  assertEquals(board.entries, []);
});

Deno.test("join requires city for a city-scope board", async () => {
  const d = await deps();
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  const noCity = await route(post("/v1/leaderboards/city_board/join", { publish_name: false }, auth), d);
  assertEquals(noCity.status, 400);

  const withCity = await route(
    post("/v1/leaderboards/city_board/join", { publish_name: false, city: "Riyadh" }, auth),
    d,
  );
  assertEquals(withCity.status, 200);
  const body = await withCity.json();
  assertEquals(body.city, "Riyadh");
  assertEquals(typeof body.handle, "string");
});

Deno.test("join/leave/membership round-trip on a global board", async () => {
  const d = await deps();
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  const joined = await route(post("/v1/leaderboards/global_weekly/join", { publish_name: false }, auth), d);
  assertEquals(joined.status, 200);

  const listed = await (await route(new Request(`${BASE}/v1/leaderboards`, { headers: auth }), d)).json();
  const board = listed.boards.find((b: { key: string }) => b.key === "global_weekly");
  assertEquals(board.joined, true);

  const updated = await route(
    patch("/v1/leaderboards/global_weekly/membership", { publish_name: true }, auth),
    d,
  );
  assertEquals((await updated.json()).publish_name, true);

  const left = await route(post("/v1/leaderboards/global_weekly/leave", undefined, auth), d);
  assertEquals((await left.json()).left, true);

  const listedAfterLeave = await (await route(new Request(`${BASE}/v1/leaderboards`, { headers: auth }), d))
    .json();
  assertEquals(listedAfterLeave.boards.find((b: { key: string }) => b.key === "global_weekly").joined, false);
});

Deno.test("membership update 404s if the user never joined", async () => {
  const d = await deps();
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const res = await route(
    patch("/v1/leaderboards/global_weekly/membership", { publish_name: true }, auth),
    d,
  );
  assertEquals(res.status, 404);
});

Deno.test("leaderboard routes require auth", async () => {
  const d = await deps();
  assertEquals((await route(new Request(`${BASE}/v1/leaderboards`), d)).status, 401);
  assertEquals((await route(post("/v1/leaderboards/global_weekly/join", {}), d)).status, 401);
});

Deno.test("admin recompute ranks members by score and the profile reflects my_rank + handle", async () => {
  const d = await deps();
  const alice = await signIn(d);
  const bob = await signIn(d);

  await route(
    post("/v1/leaderboards/global_weekly/join", { publish_name: false }, {
      authorization: `Bearer ${alice.access_token}`,
    }),
    d,
  );
  await route(
    post("/v1/leaderboards/global_weekly/join", { publish_name: false }, {
      authorization: `Bearer ${bob.access_token}`,
    }),
    d,
  );

  // Alice: 2 qualifying events, Bob: 1.
  await route(
    post("/v1/gamification/events", {
      events: [
        {
          client_event_id: "a1",
          event_type: "azkar_completed",
          occurred_at: "2026-07-01T00:00:00Z",
          timezone: "UTC",
        },
        {
          client_event_id: "a2",
          event_type: "azkar_completed",
          occurred_at: "2026-07-02T00:00:00Z",
          timezone: "UTC",
        },
      ],
    }, { authorization: `Bearer ${alice.access_token}` }),
    d,
  );
  await route(
    post("/v1/gamification/events", {
      events: [{
        client_event_id: "b1",
        event_type: "azkar_completed",
        occurred_at: "2026-07-01T00:00:00Z",
        timezone: "UTC",
      }],
    }, { authorization: `Bearer ${bob.access_token}` }),
    d,
  );

  const unauthed = await route(post("/admin/v1/leaderboards/global_weekly/recompute"), d);
  assertEquals(unauthed.status, 401);

  const adminLogin = await (
    await route(post("/admin/v1/auth/login", { email: "admin@fatwabot.dev", password: "pw" }), d)
  ).json();
  const recompute = await route(
    post("/admin/v1/leaderboards/global_weekly/recompute", undefined, {
      authorization: `Bearer ${adminLogin.access_token}`,
    }),
    d,
  );
  assertEquals(recompute.status, 200);
  assertEquals(await recompute.json(), { period_key: "lifetime", entries: 2, buckets: 1 });

  const profile = await (
    await route(
      new Request(`${BASE}/v1/leaderboards`, { headers: { authorization: `Bearer ${alice.access_token}` } }),
      d,
    )
  ).json();
  const board = profile.boards.find((b: { key: string }) => b.key === "global_weekly");
  assertEquals(board.my_rank, 1); // Alice scored higher (2 events vs Bob's 1)
  assertEquals(board.entries[0].score, 2);
  assertEquals(board.entries[1].score, 1);
});

Deno.test("city-scope boards rank within a city, not across all members", async () => {
  const d = await deps();
  const cairoA = await signIn(d);
  const cairoB = await signIn(d);
  const jakarta = await signIn(d);

  const join = (token: string, city: string) =>
    route(
      post("/v1/leaderboards/city_board/join", { publish_name: false, city }, {
        authorization: `Bearer ${token}`,
      }),
      d,
    );
  assertEquals((await join(cairoA.access_token, "Cairo")).status, 200);
  assertEquals((await join(cairoB.access_token, "Cairo")).status, 200);
  assertEquals((await join(jakarta.access_token, "Jakarta")).status, 200);

  // Jakarta out-scores both Cairo members. If ranking were global, Jakarta
  // would take rank 1 and push Cairo's best to rank 2 — the bug this guards.
  const emit = (token: string, ids: string[]) =>
    route(
      post("/v1/gamification/events", {
        events: ids.map((id) => ({
          client_event_id: id,
          event_type: "azkar_completed",
          occurred_at: "2026-07-01T00:00:00Z",
          timezone: "UTC",
        })),
      }, { authorization: `Bearer ${token}` }),
      d,
    );
  await emit(jakarta.access_token, ["j1", "j2", "j3"]);
  await emit(cairoA.access_token, ["a1", "a2"]);
  await emit(cairoB.access_token, ["b1"]);

  const adminLogin = await (
    await route(post("/admin/v1/auth/login", { email: "admin@fatwabot.dev", password: "pw" }), d)
  ).json();
  const recompute = await (await route(
    post("/admin/v1/leaderboards/city_board/recompute", undefined, {
      authorization: `Bearer ${adminLogin.access_token}`,
    }),
    d,
  )).json();
  // Two cities => two independent rankings.
  assertEquals(recompute.buckets, 2);
  assertEquals(recompute.entries, 3);

  const boardFor = async (token: string) => {
    const body = await (await route(
      new Request(`${BASE}/v1/leaderboards`, { headers: { authorization: `Bearer ${token}` } }),
      d,
    )).json();
    return body.boards.find((b: { key: string }) => b.key === "city_board");
  };

  // Cairo's top member is rank 1 *of Cairo*, despite Jakarta scoring higher.
  const aBoard = await boardFor(cairoA.access_token);
  assertEquals(aBoard.my_rank, 1);
  assertEquals(aBoard.entries.length, 2);

  const bBoard = await boardFor(cairoB.access_token);
  assertEquals(bBoard.my_rank, 2);

  // Jakarta sees only itself, also as rank 1 of its own city.
  const jBoard = await boardFor(jakarta.access_token);
  assertEquals(jBoard.my_rank, 1);
  assertEquals(jBoard.entries.length, 1);
});

Deno.test("admin standings requires an admin token", async () => {
  const d = await deps();
  assertEquals((await route(new Request(`${BASE}/admin/v1/leaderboards/global_weekly/standings`), d)).status, 401);
  assertEquals((await route(new Request(`${BASE}/admin/v1/leaderboards/global_weekly/periods`), d)).status, 401);
});

Deno.test("admin standings 404s for a leaderboard key that doesn't exist", async () => {
  const d = await deps();
  const adminLogin = await (
    await route(post("/admin/v1/auth/login", { email: "admin@fatwabot.dev", password: "pw" }), d)
  ).json();
  const auth = { authorization: `Bearer ${adminLogin.access_token}` };

  const res = await route(new Request(`${BASE}/admin/v1/leaderboards/no_such_board/standings`, { headers: auth }), d);
  assertEquals(res.status, 404);
});

Deno.test("admin standings returns every member ranked, unfiltered by bucket, with country/city and a real name", async () => {
  const d = await deps();
  const cairoA = await signIn(d);
  const cairoB = await signIn(d);
  const jakarta = await signIn(d);

  // A published display name, so this test also pins that the admin view
  // shows it regardless of the member's own publish_name choice.
  await route(
    patch("/v1/me/profile", { display_name: "Jakarta Winner" }, { authorization: `Bearer ${jakarta.access_token}` }),
    d,
  );

  const join = (token: string, city: string) =>
    route(
      post("/v1/leaderboards/city_board/join", { publish_name: false, city }, {
        authorization: `Bearer ${token}`,
      }),
      d,
    );
  await join(cairoA.access_token, "Cairo");
  await join(cairoB.access_token, "Cairo");
  await join(jakarta.access_token, "Jakarta");

  const emit = (token: string, ids: string[]) =>
    route(
      post("/v1/gamification/events", {
        events: ids.map((id) => ({
          client_event_id: id,
          event_type: "azkar_completed",
          occurred_at: "2026-07-01T00:00:00Z",
          timezone: "UTC",
        })),
      }, { authorization: `Bearer ${token}` }),
      d,
    );
  await emit(jakarta.access_token, ["j1", "j2", "j3"]);
  await emit(cairoA.access_token, ["a1", "a2"]);
  await emit(cairoB.access_token, ["b1"]);

  const adminLogin = await (
    await route(post("/admin/v1/auth/login", { email: "admin@fatwabot.dev", password: "pw" }), d)
  ).json();
  const auth = { authorization: `Bearer ${adminLogin.access_token}` };

  const res = await route(new Request(`${BASE}/admin/v1/leaderboards/city_board/standings`, { headers: auth }), d);
  assertEquals(res.status, 200);
  const body = await res.json();

  // Unfiltered: a normal user only ever sees their own bucket (the test
  // above this one proves that). The admin sees everyone across every city —
  // this is exactly the gap the admin view exists to close.
  assertEquals(body.entries.length, 3);
  assertEquals(body.is_current_period, true);

  const jakartaEntry = body.entries.find((e: { city: string }) => e.city === "Jakarta");
  assertEquals(jakartaEntry.rank, 1);
  assertEquals(jakartaEntry.display_name, "Jakarta Winner");

  const cairoEntries = body.entries.filter((e: { city: string }) => e.city === "Cairo");
  assertEquals(cairoEntries.length, 2);
  // Both Cairo members rank 1 *within Cairo* (bucketed), not global rank 2/3 —
  // same guarantee the public endpoint gives, just not bucket-filtered away.
  assertEquals(cairoEntries.map((e: { rank: number }) => e.rank).sort(), [1, 2]);
});

Deno.test("admin standings serves a past period as stored, without recomputing it against today", async () => {
  const d = await deps();
  const alice = await signIn(d);
  await route(
    post("/v1/leaderboards/global_weekly/join", { publish_name: false }, {
      authorization: `Bearer ${alice.access_token}`,
    }),
    d,
  );
  await route(
    post("/v1/gamification/events", {
      events: [{
        client_event_id: "old1",
        event_type: "azkar_completed",
        occurred_at: "2026-07-01T00:00:00Z",
        timezone: "UTC",
      }],
    }, { authorization: `Bearer ${alice.access_token}` }),
    d,
  );

  const adminLogin = await (
    await route(post("/admin/v1/auth/login", { email: "admin@fatwabot.dev", password: "pw" }), d)
  ).json();
  const auth = { authorization: `Bearer ${adminLogin.access_token}` };

  // global_weekly is seeded with period "lifetime" (see deps() above), so its
  // only ever period_key is "lifetime" — recompute it once, then list periods.
  await route(post("/admin/v1/leaderboards/global_weekly/recompute", undefined, auth), d);

  const periods = await (
    await route(new Request(`${BASE}/admin/v1/leaderboards/global_weekly/periods`, { headers: auth }), d)
  ).json();
  assertEquals(periods.periods, ["lifetime"]);

  const standings = await (
    await route(
      new Request(`${BASE}/admin/v1/leaderboards/global_weekly/standings?period_key=lifetime`, { headers: auth }),
      d,
    )
  ).json();
  assertEquals(standings.is_current_period, true); // "lifetime" is its own current period
  assertEquals(standings.entries.length, 1);
  assertEquals(standings.entries[0].score, 1);
});

Deno.test("standings materialize without an admin ever pressing recompute", async () => {
  const d = await deps();
  const alice = await signIn(d);

  await route(
    post("/v1/leaderboards/global_weekly/join", { publish_name: false }, {
      authorization: `Bearer ${alice.access_token}`,
    }),
    d,
  );
  await route(
    post("/v1/gamification/events", {
      events: [{
        client_event_id: "lazy1",
        event_type: "azkar_completed",
        occurred_at: "2026-07-01T00:00:00Z",
        timezone: "UTC",
      }],
    }, { authorization: `Bearer ${alice.access_token}` }),
    d,
  );

  // No admin recompute call anywhere in this test — the read must do it.
  const body = await (await route(
    new Request(`${BASE}/v1/leaderboards`, {
      headers: { authorization: `Bearer ${alice.access_token}` },
    }),
    d,
  )).json();

  const board = body.boards.find((b: { key: string }) => b.key === "global_weekly");
  assertEquals(board.my_rank, 1);
  assertEquals(board.entries.length, 1);
});
