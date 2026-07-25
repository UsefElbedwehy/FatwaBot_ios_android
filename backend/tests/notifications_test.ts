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
import { DevIdentityProviderVerifier } from "../functions/api/auth/provider_verify.ts";
import { InMemoryGamificationRepo } from "./in_memory_gamification_repo.ts";
import { InMemoryAnalyticsRepo } from "./in_memory_analytics_repo.ts";
import { InMemoryLeaderboardRepo } from "./in_memory_leaderboard_repo.ts";
import { InMemorySearchHistoryRepo } from "./in_memory_search_repo.ts";
import { InMemoryDeliveryLogRepo, InMemoryNotificationPrefsRepo } from "./in_memory_notification_repo.ts";
import {
  capCheckAllowed,
  DEFAULT_DAILY_CAP,
  effectiveDailyCap,
} from "../functions/api/notification_engine.ts";

const BASE = "https://x.supabase.co/functions/v1/api";
const SECRET = "test-secret";
const DEVICE = { platform: "ios", app_version: "1.0.0", locale: "ar", timezone: "Asia/Riyadh" };

function deps() {
  const adminContent = new InMemoryAdminContentRepo();
  adminContent.seed("notification-types", [
    {
      id: "nt-1",
      published: true,
      version: 1,
      fields: {
        key: "streak_reminder",
        category: "campaign",
        name_translations: { ar: "تذكير التتابع", en: "Streak Reminder" },
        help_text_translations: { ar: "", en: "" },
        default_enabled: true,
        offset_configurable: false,
        delivery_class: "remote",
      },
    },
    {
      id: "nt-draft",
      published: false,
      version: 1,
      fields: { key: "draft_type", category: "campaign", default_enabled: false },
    },
  ]);

  return {
    repo: new InMemoryConfigRepo(),
    identity: new InMemoryIdentityRepo(),
    content: new InMemoryContentRepo(),
    adminContent,
    adminUsers: new InMemoryAdminUsersRepo(),
    adminAuth: new InMemoryAdminAuthRepo(),
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

function patch(path: string, body: unknown, headers: HeadersInit = {}): Request {
  return new Request(`${BASE}${path}`, {
    method: "PATCH",
    headers: { "content-type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

async function signIn(d: ReturnType<typeof deps>) {
  return await (await route(post("/v1/auth/anonymous", { device: DEVICE }), d)).json();
}

Deno.test("GET /v1/notification-types only returns published types", async () => {
  const d = deps();
  const res = await route(new Request(`${BASE}/v1/notification-types`), d);
  const body = await res.json();
  assertEquals(body.types.length, 1);
  assertEquals(body.types[0].key, "streak_reminder");
});

Deno.test("prefs default to the catalog's default_enabled until overridden", async () => {
  const d = deps();
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  const initial = await (await route(new Request(`${BASE}/v1/me/notification-prefs`, { headers: auth }), d))
    .json();
  assertEquals(initial.prefs, [{
    notification_type_key: "streak_reminder",
    enabled: true,
    offset_minutes: null,
  }]);

  const patched = await route(
    patch("/v1/me/notification-prefs", { notification_type_key: "streak_reminder", enabled: false }, auth),
    d,
  );
  assertEquals((await patched.json()).enabled, false);

  const after = await (await route(new Request(`${BASE}/v1/me/notification-prefs`, { headers: auth }), d))
    .json();
  assertEquals(after.prefs[0].enabled, false);
});

Deno.test("prefs PATCH rejects an unknown/unpublished notification type", async () => {
  const d = deps();
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const res = await route(
    patch("/v1/me/notification-prefs", { notification_type_key: "draft_type", enabled: true }, auth),
    d,
  );
  assertEquals(res.status, 404);
});

Deno.test("notification routes require auth", async () => {
  const d = deps();
  assertEquals((await route(new Request(`${BASE}/v1/me/notification-prefs`), d)).status, 401);
});

Deno.test("marking a delivery as opened is idempotent-safe and 404s for unknown ids", async () => {
  const d = deps();
  const entry = await d.deliveryLog.record(
    { appId: "app", platform: "all", appVersion: null, locale: "ar" },
    "streak_reminder",
    "user-1",
    "sent",
  );
  const opened = await route(post(`/v1/notifications/${entry.id}/opened`), d);
  assertEquals((await opened.json()).opened, true);

  const unknown = await route(post("/v1/notifications/does-not-exist/opened"), d);
  assertEquals(unknown.status, 404);
});

Deno.test("capCheckAllowed / effectiveDailyCap: pure cap logic", () => {
  assertEquals(effectiveDailyCap(undefined), DEFAULT_DAILY_CAP);
  assertEquals(effectiveDailyCap(null), DEFAULT_DAILY_CAP);
  assertEquals(effectiveDailyCap(5), 5);
  assertEquals(capCheckAllowed(0, 2), true);
  assertEquals(capCheckAllowed(1, 2), true);
  assertEquals(capCheckAllowed(2, 2), false);
});

Deno.test("delivery log countSentSince only counts 'sent' status within the window", async () => {
  const d = deps();
  const ctx = { appId: "app", platform: "all" as const, appVersion: null, locale: "ar" };
  await d.deliveryLog.record(ctx, "c1", "user-1", "sent");
  await d.deliveryLog.record(ctx, "c1", "user-1", "capped");
  await d.deliveryLog.record(ctx, "c2", "user-1", "sent");
  await d.deliveryLog.record(ctx, "c1", "user-2", "sent"); // different user

  const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
  const count = await d.deliveryLog.countSentSince(ctx, "user-1", since);
  assertEquals(count, 2);
});
