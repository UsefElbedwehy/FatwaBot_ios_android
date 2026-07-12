import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";
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
    auditLog: new InMemoryAuditLogRepo(),
    jwtSecret: SECRET,
    verifier: new DevIdentityProviderVerifier(),
    gamification: new InMemoryGamificationRepo(),
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

function patch(path: string, body: unknown, headers: HeadersInit = {}): Request {
  return new Request(`${BASE}${path}`, {
    method: "PATCH",
    headers: { "content-type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

Deno.test("apple/google sign-in creates an account-kind user", async () => {
  const d = deps();
  const res = await route(post("/v1/auth/apple", { identity_token: "apple-subject-1", device: DEVICE }), d);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.kind, "account");
  assert(body.access_token);
});

Deno.test("signing in twice with the same provider subject reuses the same user", async () => {
  const d = deps();
  const first = await (
    await route(post("/v1/auth/google", { identity_token: "google-subject-1", device: DEVICE }), d)
  ).json();
  const second = await (
    await route(post("/v1/auth/google", { identity_token: "google-subject-1", device: DEVICE }), d)
  ).json();
  assertEquals(first.user_id, second.user_id);
});

Deno.test("provider sign-in rejects an empty identity_token", async () => {
  const res = await route(post("/v1/auth/apple", { identity_token: "", device: DEVICE }), deps());
  assertEquals(res.status, 400);
});

Deno.test("linking preserves the anonymous user_id and upgrades kind to account", async () => {
  const d = deps();
  const anon = await (await route(post("/v1/auth/anonymous", { device: DEVICE }), d)).json();

  const linkRes = await route(
    post("/v1/auth/link", { provider: "apple", identity_token: "apple-subject-2" }, {
      authorization: `Bearer ${anon.access_token}`,
    }),
    d,
  );
  assertEquals(linkRes.status, 200);
  const linkBody = await linkRes.json();
  assertEquals(linkBody.user_id, anon.user_id);

  const me = await (
    await route(
      new Request(`${BASE}/v1/me`, { headers: { authorization: `Bearer ${anon.access_token}` } }),
      d,
    )
  ).json();
  assertEquals(me.user_id, anon.user_id);
  assertEquals(me.provider, "apple");
});

Deno.test("linking rejects a provider identity already linked to a different account", async () => {
  const d = deps();
  await route(post("/v1/auth/apple", { identity_token: "shared-subject", device: DEVICE }), d);

  const anon = await (await route(post("/v1/auth/anonymous", { device: DEVICE }), d)).json();
  const res = await route(
    post("/v1/auth/link", { provider: "apple", identity_token: "shared-subject" }, {
      authorization: `Bearer ${anon.access_token}`,
    }),
    d,
  );
  assertEquals(res.status, 409);
  assertEquals((await res.json()).error.code, "already_linked");
});

Deno.test("link requires a valid bearer token", async () => {
  const res = await route(post("/v1/auth/link", { provider: "apple", identity_token: "x" }), deps());
  assertEquals(res.status, 401);
});

Deno.test("profile PATCH sets and clears display_name", async () => {
  const d = deps();
  const anon = await (await route(post("/v1/auth/anonymous", { device: DEVICE }), d)).json();
  const auth = { authorization: `Bearer ${anon.access_token}` };

  const set = await route(patch("/v1/me/profile", { display_name: "Abu Bakr" }, auth), d);
  assertEquals(set.status, 200);
  assertEquals((await set.json()).display_name, "Abu Bakr");

  const me = await (await route(new Request(`${BASE}/v1/me`, { headers: auth }), d)).json();
  assertEquals(me.display_name, "Abu Bakr");

  const cleared = await route(patch("/v1/me/profile", { display_name: null }, auth), d);
  assertEquals((await cleared.json()).display_name, null);
});

Deno.test("profile PATCH validates display_name length and requires auth", async () => {
  const d = deps();
  const anon = await (await route(post("/v1/auth/anonymous", { device: DEVICE }), d)).json();
  const auth = { authorization: `Bearer ${anon.access_token}` };

  const tooLong = await route(patch("/v1/me/profile", { display_name: "x".repeat(51) }, auth), d);
  assertEquals(tooLong.status, 400);

  const missingField = await route(patch("/v1/me/profile", {}, auth), d);
  assertEquals(missingField.status, 400);

  const noAuth = await route(patch("/v1/me/profile", { display_name: "x" }), d);
  assertEquals(noAuth.status, 401);
});

Deno.test("account linking never resets the user_id gamification/state would key off of", async () => {
  const d = deps();
  const anon = await (await route(post("/v1/auth/anonymous", { device: DEVICE }), d)).json();
  await route(
    post("/v1/auth/link", { provider: "google", identity_token: "google-subject-99" }, {
      authorization: `Bearer ${anon.access_token}`,
    }),
    d,
  );
  const relinkAttempt = await route(
    post("/v1/auth/link", { provider: "google", identity_token: "google-subject-99" }, {
      authorization: `Bearer ${anon.access_token}`,
    }),
    d,
  );
  // Re-linking the SAME identity to the SAME already-linked user is a no-op success, not a conflict.
  assertEquals(relinkAttempt.status, 200);
  assertNotEquals(relinkAttempt.status, 409);
});

Deno.test("push-token registers and clears the device's FCM token", async () => {
  const d = deps();
  const anonRes = await route(post("/v1/auth/anonymous", { device: DEVICE }), d);
  const anon = await anonRes.json();
  const auth = { authorization: `Bearer ${anon.access_token}` };

  // Register a token.
  const reg = await route(patch("/v1/me/push-token", { push_token: "fcm-token-abc" }, auth), d);
  assertEquals(reg.status, 200);
  assertEquals((await reg.json()).registered, true);
  const device = [...d.identity.devices.values()].find((x) => x.userId === anon.user_id);
  assertEquals(device?.pushToken, "fcm-token-abc");

  // Clear it.
  const clear = await route(patch("/v1/me/push-token", { push_token: null }, auth), d);
  assertEquals(clear.status, 200);
  assertEquals((await clear.json()).registered, false);
  const cleared = [...d.identity.devices.values()].find((x) => x.userId === anon.user_id);
  assertEquals(cleared?.pushToken, null);
});

Deno.test("push-token requires a bearer token", async () => {
  const d = deps();
  const res = await route(patch("/v1/me/push-token", { push_token: "x" }), d);
  assertEquals(res.status, 401);
});
