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

async function deps() {
  const adminAuth = new InMemoryAdminAuthRepo();
  adminAuth.admins.set("admin@fatwabot.app", {
    id: "admin-1",
    passwordHash: await bcrypt.hash("correct-horse-battery-staple", 10),
  });
  return {
    repo: new InMemoryConfigRepo(),
    identity: new InMemoryIdentityRepo(),
    content: new InMemoryContentRepo(),
    adminContent: new InMemoryAdminContentRepo(),
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

function post(path: string, body: unknown, headers: HeadersInit = {}): Request {
  return new Request(`${BASE}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

function get(path: string, headers: HeadersInit = {}): Request {
  return new Request(`${BASE}${path}`, { headers });
}

Deno.test("admin login succeeds with correct credentials", async () => {
  const res = await route(
    post("/admin/v1/auth/login", { email: "admin@fatwabot.app", password: "correct-horse-battery-staple" }),
    await deps(),
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.admin_id, "admin-1");
  assertEquals(typeof body.access_token, "string");
});

Deno.test("admin login rejects wrong password", async () => {
  const res = await route(
    post("/admin/v1/auth/login", { email: "admin@fatwabot.app", password: "wrong" }),
    await deps(),
  );
  assertEquals(res.status, 401);
});

Deno.test("admin login rejects unknown email", async () => {
  const res = await route(
    post("/admin/v1/auth/login", { email: "nope@fatwabot.app", password: "x" }),
    await deps(),
  );
  assertEquals(res.status, 401);
});

Deno.test("admin login validates request body", async () => {
  const res = await route(post("/admin/v1/auth/login", { email: "a@b.com" }), await deps());
  assertEquals(res.status, 400);
});

Deno.test("admin routes reject missing bearer token", async () => {
  const res = await route(get("/admin/v1/content/azkar-categories"), await deps());
  assertEquals(res.status, 401);
});

Deno.test("admin routes reject a mobile (non-admin) access token", async () => {
  const d = await deps();
  // A mobile anonymous-auth token has no "admin" audience — must be rejected here.
  const anon = await (
    await route(
      post("/v1/auth/anonymous", {
        device: { platform: "ios", app_version: "1.0.0", locale: "ar", timezone: "UTC" },
      }),
      d,
    )
  ).json();
  const res = await route(
    get("/admin/v1/content/azkar-categories", { authorization: `Bearer ${anon.access_token}` }),
    d,
  );
  assertEquals(res.status, 401);
});

Deno.test("valid admin token grants access", async () => {
  const d = await deps();
  const login = await (
    await route(
      post("/admin/v1/auth/login", { email: "admin@fatwabot.app", password: "correct-horse-battery-staple" }),
      d,
    )
  ).json();
  const res = await route(
    get("/admin/v1/content/azkar-categories", { authorization: `Bearer ${login.access_token}` }),
    d,
  );
  assertEquals(res.status, 200);
});
