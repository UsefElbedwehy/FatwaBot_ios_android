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
  return {
    repo: new InMemoryConfigRepo(),
    identity: new InMemoryIdentityRepo(),
    content: new InMemoryContentRepo(),
    adminContent: new InMemoryAdminContentRepo(),
    adminUsers: new InMemoryAdminUsersRepo(),
    adminAuth,
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

async function authedRequest(
  d: Awaited<ReturnType<typeof makeDeps>>,
  method: string,
  path: string,
  body?: unknown,
): Promise<Response> {
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
  const req = new Request(`${BASE}${path}`, {
    method,
    headers: {
      authorization: `Bearer ${login.access_token}`,
      ...(body !== undefined ? { "content-type": "application/json" } : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  return await route(req, d);
}

Deno.test("unknown collection 404s on every verb", async () => {
  const d = await makeDeps();
  assertEquals((await authedRequest(d, "GET", "/admin/v1/content/not-a-collection")).status, 404);
  assertEquals(
    (await authedRequest(d, "POST", "/admin/v1/content/not-a-collection", {})).status,
    404,
  );
});

Deno.test("create makes a draft (unpublished, version 1)", async () => {
  const d = await makeDeps();
  const res = await authedRequest(d, "POST", "/admin/v1/content/azkar-categories", {
    slug: "morning",
    name_translations: { ar: "أذكار الصباح" },
  });
  assertEquals(res.status, 201);
  const row = await res.json();
  assertEquals(row.published, false);
  assertEquals(row.version, 1);
  assertExists(row.id);
});

Deno.test("publish flips published; unpublish reverts", async () => {
  const d = await makeDeps();
  const created = await (
    await authedRequest(d, "POST", "/admin/v1/content/azkar-categories", { slug: "evening" })
  ).json();

  const published = await (
    await authedRequest(d, "POST", `/admin/v1/content/azkar-categories/${created.id}/publish`)
  ).json();
  assertEquals(published.published, true);

  const unpublished = await (
    await authedRequest(d, "POST", `/admin/v1/content/azkar-categories/${created.id}/unpublish`)
  ).json();
  assertEquals(unpublished.published, false);
});

Deno.test("version bumps only on published-row edits, not draft edits", async () => {
  const d = await makeDeps();
  const created = await (
    await authedRequest(d, "POST", "/admin/v1/content/azkar-categories", { slug: "after_prayer" })
  ).json();
  assertEquals(created.version, 1);

  // Draft edit: version unchanged.
  const draftEdited = await (
    await authedRequest(d, "PATCH", `/admin/v1/content/azkar-categories/${created.id}`, {
      slug: "after-salah",
    })
  ).json();
  assertEquals(draftEdited.version, 1, "draft-to-draft edits must not bump version");

  await authedRequest(d, "POST", `/admin/v1/content/azkar-categories/${created.id}/publish`);

  // Published-row edit: version bumps.
  const publishedEdited = await (
    await authedRequest(d, "PATCH", `/admin/v1/content/azkar-categories/${created.id}`, {
      slug: "after-salah-2",
    })
  ).json();
  assertEquals(publishedEdited.version, 2, "editing an already-published row must bump version");
});

Deno.test("update on unknown id 404s", async () => {
  const d = await makeDeps();
  const res = await authedRequest(d, "PATCH", "/admin/v1/content/azkar-categories/does-not-exist", {
    slug: "x",
  });
  assertEquals(res.status, 404);
});

Deno.test("every mutation writes an audit log entry", async () => {
  const d = await makeDeps();
  const created = await (
    await authedRequest(d, "POST", "/admin/v1/content/wird-templates", {
      name_translations: { ar: "استغفار" },
    })
  ).json();
  await authedRequest(d, "PATCH", `/admin/v1/content/wird-templates/${created.id}`, { type: "istighfar" });
  await authedRequest(d, "POST", `/admin/v1/content/wird-templates/${created.id}/publish`);

  const log = await (await authedRequest(d, "GET", "/admin/v1/audit-log")).json();
  const actions = log.entries.map((e: { action: string }) => e.action);
  assertEquals(actions, ["publish", "update", "create"], "most recent first");
  assertEquals(log.entries.every((e: { adminId: string }) => e.adminId === "admin-1"), true);
});

Deno.test("audit log filters by collection", async () => {
  const d = await makeDeps();
  await authedRequest(d, "POST", "/admin/v1/content/wird-templates", { name_translations: {} });
  await authedRequest(d, "POST", "/admin/v1/content/azkar-categories", { slug: "morning" });

  const filtered = await (
    await authedRequest(d, "GET", "/admin/v1/audit-log?collection=wird-templates")
  ).json();
  assertEquals(filtered.entries.length, 1);
  assertEquals(filtered.entries[0].collection, "wird-templates");
});

Deno.test("PATCH is rejected on the list endpoint (method not allowed)", async () => {
  const d = await makeDeps();
  const res = await authedRequest(d, "PATCH", "/admin/v1/content/azkar-categories", {});
  assertEquals(res.status, 405);
});
