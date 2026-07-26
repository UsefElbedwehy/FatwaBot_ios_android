import { assertEquals, assertExists } from "jsr:@std/assert@1";
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

const BASE = "https://x.supabase.co/functions/v1/api";
const SECRET = "test-secret";

async function makeDeps() {
  const adminAuth = new InMemoryAdminAuthRepo();
  adminAuth.admins.set("admin@fatwabot.app", { id: "admin-1", passwordHash: await bcrypt.hash("pw", 10) });
  const adminStrings = new InMemoryAdminStringsRepo();
  const auditLog = new InMemoryAuditLogRepo();
  return {
    repo: new InMemoryConfigRepo(),
    identity: new InMemoryIdentityRepo(),
    content: new InMemoryContentRepo(),
    adminContent: new InMemoryAdminContentRepo(),
    adminUsers: new InMemoryAdminUsersRepo(),
    adminAuth,
    adminStrings,
    auditLog,
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

type Deps = Awaited<ReturnType<typeof makeDeps>>;

async function authedRequest(d: Deps, method: string, path: string, body?: unknown): Promise<Response> {
  const login = await (
    await route(
      new Request(`${BASE}/admin/v1/auth/login`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email: "admin@fatwabot.app", password: "pw" }),
      }),
      d,
    )
  ).json();
  return await route(
    new Request(`${BASE}${path}`, {
      method,
      headers: {
        authorization: `Bearer ${login.access_token}`,
        ...(body !== undefined ? { "content-type": "application/json" } : {}),
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
    }),
    d,
  );
}

Deno.test("string-pack routes require an admin token", async () => {
  const d = await makeDeps();
  const paths = ["/admin/v1/string-packs", "/admin/v1/string-packs/ar", "/admin/v1/string-packs/ar/1"];
  for (const path of paths) {
    const res = await route(new Request(`${BASE}${path}`), d);
    assertEquals(res.status, 401, path);
    assertEquals((await res.json()).error.code, "unauthorized");
  }
});

Deno.test("GET /string-packs summarises published + draft version per locale", async () => {
  const d = await makeDeps();
  d.adminStrings.seed([
    { locale: "ar", version: 1, published: true, strings: { "a": "١" } },
    { locale: "ar", version: 2, published: true, strings: { "a": "١", "b": "٢" } },
    { locale: "ar", version: 3, published: false, strings: { "a": "١", "b": "٢", "c": "٣" } },
    { locale: "en", version: 7, published: true, strings: { "a": "1" } },
    { locale: "fr", version: 1, published: false, strings: {} },
  ]);

  const body = await (await authedRequest(d, "GET", "/admin/v1/string-packs")).json();
  assertEquals(body.locales, [
    { locale: "ar", published_version: 2, draft_version: 3, key_count: 3 },
    { locale: "en", published_version: 7, draft_version: null, key_count: 1 },
    { locale: "fr", published_version: null, draft_version: 1, key_count: 0 },
  ]);
});

Deno.test("GET /string-packs/{locale} opens on the newest version (draft above published)", async () => {
  const d = await makeDeps();
  d.adminStrings.seed([
    { locale: "ar", version: 4, published: true, strings: { "tasbeeh.notice": "منشور" } },
    { locale: "ar", version: 5, published: false, strings: { "tasbeeh.notice": "مسودة" } },
  ]);

  const newest = await (await authedRequest(d, "GET", "/admin/v1/string-packs/ar")).json();
  assertEquals(newest.version, 5);
  assertEquals(newest.published, false);
  assertEquals(newest.strings["tasbeeh.notice"], "مسودة");
});

Deno.test("GET /string-packs/{locale}?version=N fetches that exact version", async () => {
  const d = await makeDeps();
  d.adminStrings.seed([
    { locale: "ar", version: 4, published: true, strings: { "tasbeeh.notice": "منشور" } },
    { locale: "ar", version: 5, published: false, strings: { "tasbeeh.notice": "مسودة" } },
  ]);

  const pinned = await (await authedRequest(d, "GET", "/admin/v1/string-packs/ar?version=4")).json();
  assertEquals(pinned.version, 4);
  assertEquals(pinned.published, true);

  const bad = await authedRequest(d, "GET", "/admin/v1/string-packs/ar?version=abc");
  assertEquals(bad.status, 400);
  assertEquals((await bad.json()).error.code, "invalid_version");

  const missing = await authedRequest(d, "GET", "/admin/v1/string-packs/ar?version=99");
  assertEquals(missing.status, 404);
  assertEquals((await missing.json()).error.code, "no_pack");
});

Deno.test("GET /string-packs/{locale} 404s no_pack for a locale with no packs", async () => {
  const d = await makeDeps();
  const res = await authedRequest(d, "GET", "/admin/v1/string-packs/de");
  assertEquals(res.status, 404);
  assertEquals((await res.json()).error.code, "no_pack");
});

Deno.test("POST creates version 1 for a locale that has no pack yet", async () => {
  const d = await makeDeps();
  const res = await authedRequest(d, "POST", "/admin/v1/string-packs/en", {
    strings: { "tasbeeh.notice": "Placeholder" },
    published: false,
  });
  assertEquals(res.status, 201);
  const pack = await res.json();
  assertEquals(pack, {
    locale: "en",
    version: 1,
    published: false,
    strings: { "tasbeeh.notice": "Placeholder" },
  });
});

Deno.test("POST publishes as a NEW version, leaving the old published version intact", async () => {
  const d = await makeDeps();
  d.adminStrings.seed([{ locale: "ar", version: 3, published: true, strings: { "k": "old" } }]);

  const pack = await (
    await authedRequest(d, "POST", "/admin/v1/string-packs/ar", {
      strings: { "k": "new" },
      published: true,
    })
  ).json();
  assertEquals(pack.version, 4, "publishing must insert a higher version, never edit v3 in place");
  assertEquals(pack.published, true);

  // v3 is untouched: multiple published versions coexist and the max wins
  // (SupabaseConfigRepo.publishedStringPack), so publishing does not unpublish.
  const old = await (await authedRequest(d, "GET", "/admin/v1/string-packs/ar?version=3")).json();
  assertEquals(old.published, true);
  assertEquals(old.strings["k"], "old");
});

Deno.test("POST numbers from max(version) across ALL rows, even when a draft occupies published+1", async () => {
  // Regression guard for the bug called out in migration 0024: numbering from
  // max(published) + 1 collides with an unpublished draft parked at that
  // number, and the insert is then either lost or overwrites the draft.
  const d = await makeDeps();
  d.adminStrings.seed([
    { locale: "ar", version: 1, published: true, strings: { "k": "v1" } },
    { locale: "ar", version: 2, published: true, strings: { "k": "v2" } },
    { locale: "ar", version: 3, published: false, strings: { "k": "draft-v3" } }, // max(published)+1
  ]);

  const pack = await (
    await authedRequest(d, "POST", "/admin/v1/string-packs/ar", { strings: { "k": "v4" }, published: true })
  ).json();
  assertEquals(pack.version, 4, "must be max(ALL versions)+1, not max(published)+1");

  // The draft that sat at the colliding number is still there, unmodified.
  const draft = await (await authedRequest(d, "GET", "/admin/v1/string-packs/ar?version=3")).json();
  assertEquals(draft.published, false);
  assertEquals(draft.strings["k"], "draft-v3");
  assertEquals(d.adminStrings.packs.length, 4, "insert must not have replaced the draft row");
});

Deno.test("POST rejects non-string values, oversized packs, and bad bodies", async () => {
  const d = await makeDeps();

  const nested = await authedRequest(d, "POST", "/admin/v1/string-packs/ar", {
    strings: { "ok": "text", "bad": { ar: "nested" } },
    published: false,
  });
  assertEquals(nested.status, 400);
  assertEquals((await nested.json()).error.code, "invalid_strings");

  for (const value of [42, true, null, ["a"]]) {
    const res = await authedRequest(d, "POST", "/admin/v1/string-packs/ar", {
      strings: { "bad": value },
      published: false,
    });
    assertEquals(res.status, 400, `value ${JSON.stringify(value)} must be rejected`);
    assertEquals((await res.json()).error.code, "invalid_strings");
  }

  const notAnObject = await authedRequest(d, "POST", "/admin/v1/string-packs/ar", {
    strings: ["a", "b"],
    published: false,
  });
  assertEquals(notAnObject.status, 400);
  assertEquals((await notAnObject.json()).error.code, "invalid_strings");

  const tooManyKeys = await authedRequest(d, "POST", "/admin/v1/string-packs/ar", {
    strings: Object.fromEntries(Array.from({ length: 2001 }, (_, i) => [`k${i}`, "v"])),
    published: false,
  });
  assertEquals(tooManyKeys.status, 400);
  assertEquals((await tooManyKeys.json()).error.code, "invalid_strings");

  const longKey = await authedRequest(d, "POST", "/admin/v1/string-packs/ar", {
    strings: { ["k".repeat(513)]: "v" },
    published: false,
  });
  assertEquals(longKey.status, 400);
  assertEquals((await longKey.json()).error.code, "invalid_strings");

  const longValue = await authedRequest(d, "POST", "/admin/v1/string-packs/ar", {
    strings: { "k": "v".repeat(4001) },
    published: false,
  });
  assertEquals(longValue.status, 400);
  assertEquals((await longValue.json()).error.code, "invalid_strings");

  const badPublished = await authedRequest(d, "POST", "/admin/v1/string-packs/ar", {
    strings: { "k": "v" },
    published: "yes",
  });
  assertEquals(badPublished.status, 400);
  assertEquals((await badPublished.json()).error.code, "invalid_body");

  assertEquals(d.adminStrings.packs.length, 0, "no rejected request may have written a row");
});

Deno.test("PATCH flips published on an existing version; 404s on a missing one", async () => {
  const d = await makeDeps();
  d.adminStrings.seed([{ locale: "ar", version: 2, published: false, strings: { "k": "v" } }]);

  const published = await (
    await authedRequest(d, "PATCH", "/admin/v1/string-packs/ar/2", { published: true })
  ).json();
  assertEquals(published.published, true);
  assertEquals(published.version, 2);

  const unpublished = await (
    await authedRequest(d, "PATCH", "/admin/v1/string-packs/ar/2", { published: false })
  ).json();
  assertEquals(unpublished.published, false);

  const missing = await authedRequest(d, "PATCH", "/admin/v1/string-packs/ar/9", { published: true });
  assertEquals(missing.status, 404);
  assertEquals((await missing.json()).error.code, "no_pack");

  const badBody = await authedRequest(d, "PATCH", "/admin/v1/string-packs/ar/2", { published: "yes" });
  assertEquals(badBody.status, 400);
  assertEquals((await badBody.json()).error.code, "invalid_body");
});

Deno.test("every string-pack mutation writes an audit row keyed locale:version", async () => {
  const d = await makeDeps();
  await authedRequest(d, "POST", "/admin/v1/string-packs/ar", {
    strings: { "k": "draft" },
    published: false,
  });
  await authedRequest(d, "POST", "/admin/v1/string-packs/ar", { strings: { "k": "live" }, published: true });
  await authedRequest(d, "PATCH", "/admin/v1/string-packs/ar/1", { published: true });
  await authedRequest(d, "PATCH", "/admin/v1/string-packs/ar/2", { published: false });

  const log = await (await authedRequest(d, "GET", "/admin/v1/audit-log?collection=string-packs")).json();
  assertEquals(
    log.entries.map((e: { action: string; rowId: string }) => [e.action, e.rowId]),
    [["unpublish", "ar:2"], ["publish", "ar:1"], ["publish", "ar:2"], ["create", "ar:1"]],
    "most recent first",
  );
  assertEquals(log.entries.every((e: { adminId: string }) => e.adminId === "admin-1"), true);

  // The version-creating entries carry the full pack; flag flips carry only the
  // flag, so the diff isn't buried under an unchanged copy of every string.
  const createEntry = log.entries.find((e: { action: string }) => e.action === "create");
  assertEquals(createEntry.before, null);
  assertEquals(createEntry.after.strings, { "k": "draft" });
  const unpublishEntry = log.entries[0];
  assertEquals(unpublishEntry.before, { locale: "ar", version: 2, published: true });
  assertEquals(unpublishEntry.after, { locale: "ar", version: 2, published: false });
  assertExists(log.entries[0].createdAtEpochSeconds);
});

Deno.test("unsupported methods on string-pack routes are 405", async () => {
  const d = await makeDeps();
  assertEquals((await authedRequest(d, "POST", "/admin/v1/string-packs", {})).status, 405);
  assertEquals((await authedRequest(d, "PATCH", "/admin/v1/string-packs/ar", {})).status, 405);
  assertEquals((await authedRequest(d, "POST", "/admin/v1/string-packs/ar/1", {})).status, 405);
});
