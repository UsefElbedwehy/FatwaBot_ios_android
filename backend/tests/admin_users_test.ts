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
import type { AdminUserRow } from "../functions/api/admin_types.ts";
import { DevIdentityProviderVerifier } from "../functions/api/auth/provider_verify.ts";
import { InMemoryGamificationRepo } from "./in_memory_gamification_repo.ts";
import { InMemoryAnalyticsRepo } from "./in_memory_analytics_repo.ts";
import { InMemoryLeaderboardRepo } from "./in_memory_leaderboard_repo.ts";
import { InMemorySearchHistoryRepo } from "./in_memory_search_repo.ts";
import { InMemoryDeliveryLogRepo, InMemoryNotificationPrefsRepo } from "./in_memory_notification_repo.ts";
import { InMemoryFatwaSearchRepo } from "./in_memory_fatwa_repo.ts";

const BASE = "https://x.supabase.co/functions/v1/api";
const SECRET = "test-secret";

function user(id: string, overrides: Partial<AdminUserRow> = {}): AdminUserRow {
  return {
    id,
    kind: "anonymous",
    provider: "anonymous",
    displayName: null,
    countryCode: null,
    createdAtEpochSeconds: 1_700_000_000,
    linkedAtEpochSeconds: null,
    ...overrides,
  };
}

async function makeDeps() {
  const adminAuth = new InMemoryAdminAuthRepo();
  adminAuth.admins.set("admin@fatwabot.app", { id: "admin-1", passwordHash: await bcrypt.hash("pw", 10) });
  const adminUsers = new InMemoryAdminUsersRepo();
  return {
    d: {
      repo: new InMemoryConfigRepo(),
      identity: new InMemoryIdentityRepo(),
      content: new InMemoryContentRepo(),
      adminContent: new InMemoryAdminContentRepo(),
      adminUsers,
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
    },
    adminUsers,
  };
}

async function authedRequest(
  d: Awaited<ReturnType<typeof makeDeps>>["d"],
  path: string,
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
  return await route(
    new Request(`${BASE}${path}`, { headers: { authorization: `Bearer ${login.access_token}` } }),
    d,
  );
}

Deno.test("GET /admin/v1/users lists most recent first", async () => {
  const { d, adminUsers } = await makeDeps();
  adminUsers.seed([
    user("u1", { createdAtEpochSeconds: 100 }),
    user("u2", { createdAtEpochSeconds: 300 }),
    user("u3", { createdAtEpochSeconds: 200 }),
  ]);

  const body = await (await authedRequest(d, "/admin/v1/users")).json();

  assertEquals(body.users.map((u: AdminUserRow) => u.id), ["u2", "u3", "u1"]);
});

Deno.test("GET /admin/v1/users?query filters by display name", async () => {
  const { d, adminUsers } = await makeDeps();
  adminUsers.seed([
    user("u1", { displayName: "Zeko" }),
    user("u2", { displayName: "Ahmed" }),
  ]);

  const body = await (await authedRequest(d, "/admin/v1/users?query=zek")).json();

  assertEquals(body.users.map((u: AdminUserRow) => u.id), ["u1"]);
});

Deno.test("GET /admin/v1/users rejects an out-of-range limit", async () => {
  const { d } = await makeDeps();
  assertEquals((await authedRequest(d, "/admin/v1/users?limit=0")).status, 400);
  assertEquals((await authedRequest(d, "/admin/v1/users?limit=201")).status, 400);
});

Deno.test("GET /admin/v1/users requires admin auth", async () => {
  const { d } = await makeDeps();
  const res = await route(new Request(`${BASE}/admin/v1/users`), d);
  assertEquals(res.status, 401);
});
