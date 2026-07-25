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

const BASE = "https://x.supabase.co/functions/v1/api";
const SECRET = "test-secret";
const DEVICE = { platform: "ios", app_version: "1.0.0", locale: "ar", timezone: "Asia/Riyadh" };

function deps() {
  const adminContent = new InMemoryAdminContentRepo();
  adminContent.seed("streak-defs", [
    {
      id: "streak-1",
      published: true,
      version: 1,
      fields: {
        key: "azkar_streak",
        name_translations: { ar: "تتابع الأذكار", en: "Azkar Streak" },
        event_types: ["azkar_completed"],
        required_daily_count: 1,
        day_boundary_type: "midnight",
        day_boundary_local_time: "04:00",
        grace_allowance: 0,
        grace_period_days: 30,
        enabled: true,
      },
    },
    {
      id: "streak-draft",
      published: false,
      version: 1,
      fields: { key: "unpublished_streak", event_types: ["x"], required_daily_count: 1 },
    },
  ]);
  adminContent.seed("missions", [
    {
      id: "mission-1",
      published: true,
      version: 1,
      fields: {
        key: "weekly_tasbeeh",
        name_translations: { ar: "التسبيح الأسبوعي", en: "Weekly Tasbeeh" },
        event_type: "tasbeeh_session_completed",
        target_count: 3,
        progress_window: "lifetime",
        schedule: "weekly",
        starts_at: null,
        ends_at: null,
      },
    },
  ]);
  adminContent.seed("badges", [
    {
      id: "badge-1",
      published: true,
      version: 1,
      fields: {
        key: "first_azkar",
        name_translations: { ar: "أول أذكار", en: "First Azkar" },
        icon_ref: "badge_first_azkar",
        event_type: "azkar_completed",
        target_count: 1,
        progress_window: "lifetime",
        hidden_until_earned: false,
      },
    },
    {
      id: "badge-hidden",
      published: true,
      version: 1,
      fields: {
        key: "secret_badge",
        name_translations: { ar: "شارة سرية", en: "Secret Badge" },
        icon_ref: "badge_secret",
        event_type: "azkar_completed",
        target_count: 100,
        progress_window: "lifetime",
        hidden_until_earned: true,
      },
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

Deno.test("event ingest is idempotent — resubmitting a client_event_id doesn't double count", async () => {
  const d = deps();
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  const first = await route(
    post("/v1/gamification/events", {
      events: [{
        client_event_id: "evt-1",
        event_type: "azkar_completed",
        occurred_at: "2026-07-06T06:00:00Z",
        timezone: "Asia/Riyadh",
      }],
    }, auth),
    d,
  );
  assertEquals(await first.json(), { accepted: 1, duplicates: 0 });

  const replay = await route(
    post("/v1/gamification/events", {
      events: [{
        client_event_id: "evt-1",
        event_type: "azkar_completed",
        occurred_at: "2026-07-06T06:00:00Z",
        timezone: "Asia/Riyadh",
      }],
    }, auth),
    d,
  );
  assertEquals(await replay.json(), { accepted: 0, duplicates: 1 });
});

Deno.test("event ingest requires auth and validates event shape", async () => {
  const d = deps();
  const noAuth = await route(post("/v1/gamification/events", { events: [] }), d);
  assertEquals(noAuth.status, 401);

  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const empty = await route(post("/v1/gamification/events", { events: [] }, auth), d);
  assertEquals(empty.status, 400);

  const malformed = await route(post("/v1/gamification/events", { events: [{ event_type: "x" }] }, auth), d);
  assertEquals(malformed.status, 400);
});

Deno.test("gamification profile assembles streaks/missions/badges from published defs only", async () => {
  const d = deps();
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  // Timestamped at "now" (not a hardcoded date) so the streak's current-day
  // check against wall-clock "today" doesn't go stale as real time passes.
  const now = new Date().toISOString();
  await route(
    post("/v1/gamification/events", {
      events: [
        { client_event_id: "e1", event_type: "azkar_completed", occurred_at: now, timezone: "Asia/Riyadh" },
        {
          client_event_id: "e2",
          event_type: "tasbeeh_session_completed",
          occurred_at: now,
          timezone: "Asia/Riyadh",
        },
      ],
    }, auth),
    d,
  );

  const profile = await (
    await route(new Request(`${BASE}/v1/gamification/profile?timezone=Asia/Riyadh`, { headers: auth }), d)
  ).json();

  assertEquals(profile.streaks.length, 1); // the unpublished streak def is excluded
  assertEquals(profile.streaks[0].key, "azkar_streak");
  assertEquals(profile.streaks[0].current_length, 1);

  assertEquals(profile.missions.length, 1);
  assertEquals(profile.missions[0].progress, 1);
  assertEquals(profile.missions[0].target, 3);

  // Earned badge visible; hidden-until-earned badge not yet met so it's excluded from the list.
  const badgeKeys = profile.badges.map((b: { key: string }) => b.key);
  assertEquals(badgeKeys, ["first_azkar"]);
  assertEquals(profile.badges[0].earned_at !== null, true);
});

Deno.test("gamification profile requires auth", async () => {
  const res = await route(new Request(`${BASE}/v1/gamification/profile`), deps());
  assertEquals(res.status, 401);
});
