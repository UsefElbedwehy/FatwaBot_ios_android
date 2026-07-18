import { assert, assertEquals } from "jsr:@std/assert@1";
import { exportPKCS8, generateKeyPair } from "npm:jose@5";
import { FcmSender, parseServiceAccount } from "../functions/api/fcm_sender.ts";
import { dispatchCampaign } from "../functions/api/notification_dispatch.ts";
import type { PushMessage, PushResult, PushSender } from "../functions/api/fcm_sender.ts";
import { InMemoryDeliveryLogRepo, InMemoryNotificationPrefsRepo } from "./in_memory_notification_repo.ts";
import type { AppContext } from "../functions/api/types.ts";

const CTX: AppContext = { appId: "app", platform: "all", appVersion: null, locale: "ar" };

async function fakeServiceAccount() {
  const { privateKey } = await generateKeyPair("RS256", { extractable: true });
  return {
    project_id: "fatwabot-test",
    client_email: "svc@fatwabot-test.iam.gserviceaccount.com",
    private_key: await exportPKCS8(privateKey),
    token_uri: "https://oauth2.example/token",
  };
}

Deno.test("parseServiceAccount rejects a malformed account", () => {
  let threw = false;
  try {
    parseServiceAccount(JSON.stringify({ project_id: "p" }));
  } catch {
    threw = true;
  }
  assert(threw);
});

Deno.test("FcmSender mints a token and posts a well-formed FCM message", async () => {
  const sa = await fakeServiceAccount();
  const calls: { url: string; init: RequestInit }[] = [];
  const fakeFetch = ((url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), init: init ?? {} });
    if (String(url) === sa.token_uri) {
      return Promise.resolve(new Response(JSON.stringify({ access_token: "at-123", expires_in: 3600 }), { status: 200 }));
    }
    return Promise.resolve(new Response(JSON.stringify({ name: "projects/x/messages/1" }), { status: 200 }));
  }) as typeof fetch;

  const sender = new FcmSender(sa, { fetch: fakeFetch, now: () => 1_000_000 });
  const res = await sender.send("device-token-1", { title: "عنوان", body: "نص", data: { campaign_key: "c1" } });
  assertEquals(res.ok, true);

  const fcm = calls.find((c) => c.url.includes("fcm.googleapis.com"))!;
  assertEquals(fcm.url, "https://fcm.googleapis.com/v1/projects/fatwabot-test/messages:send");
  assertEquals((fcm.init.headers as Record<string, string>).authorization, "Bearer at-123");
  const payload = JSON.parse(fcm.init.body as string);
  assertEquals(payload.message.token, "device-token-1");
  assertEquals(payload.message.notification.title, "عنوان");
  assertEquals(payload.message.data.campaign_key, "c1");

  // Token is cached — a second send reuses it (only one token-exchange call).
  await sender.send("device-token-2", { title: "t", body: "b" });
  assertEquals(calls.filter((c) => c.url === sa.token_uri).length, 1);
});

Deno.test("FcmSender flags an unregistered token", async () => {
  const sa = await fakeServiceAccount();
  const fakeFetch = ((url: string | URL | Request) => {
    if (String(url) === sa.token_uri) {
      return Promise.resolve(new Response(JSON.stringify({ access_token: "at", expires_in: 3600 }), { status: 200 }));
    }
    return Promise.resolve(new Response(JSON.stringify({ error: { status: "NOT_FOUND" } }), { status: 404 }));
  }) as typeof fetch;
  const sender = new FcmSender(sa, { fetch: fakeFetch, now: () => 0 });
  const res = await sender.send("dead-token", { title: "t", body: "b" });
  assertEquals(res.ok, false);
  assertEquals(res.unregistered, true);
});

// --- dispatch ---

class FakeSender implements PushSender {
  sent: string[] = [];
  constructor(private readonly result: (token: string) => PushResult = () => ({ ok: true })) {}
  send(token: string, _m: PushMessage): Promise<PushResult> {
    this.sent.push(token);
    return Promise.resolve(this.result(token));
  }
}

function dispatchDeps() {
  const notificationPrefs = new InMemoryNotificationPrefsRepo();
  const deliveryLog = new InMemoryDeliveryLogRepo();
  const cleared: string[] = [];
  return {
    notificationPrefs,
    deliveryLog,
    cleared,
    deps: {
      notificationPrefs,
      deliveryLog,
      clearToken: (userId: string) => {
        cleared.push(userId);
        return Promise.resolve();
      },
    },
  };
}

const campaign = {
  campaignKey: "ramadan-1",
  notificationTypeKey: "campaign_general",
  defaultEnabled: true,
  dailyCapOverride: null as number | null,
  title: "t",
  body: "b",
};
const SINCE = new Date("2026-03-20T00:00:00Z");

Deno.test("dispatch sends to opted-in devices and skips opted-out", async () => {
  const h = dispatchDeps();
  await h.notificationPrefs.upsert(CTX, "user-off", {
    notificationTypeKey: "campaign_general",
    enabled: false,
    offsetMinutes: null,
  });
  const sender = new FakeSender();
  const summary = await dispatchCampaign(CTX, h.deps, campaign, [
    { userId: "user-on", token: "tok-on" },
    { userId: "user-off", token: "tok-off" },
  ], sender, SINCE);

  assertEquals(summary.sent, 1);
  assertEquals(summary.skipped, 1);
  assertEquals(sender.sent, ["tok-on"]);
});

Deno.test("dispatch enforces the daily cap", async () => {
  const h = dispatchDeps();
  // Two campaign sends already today (default cap = 2) → the 3rd is capped.
  await h.deliveryLog.record(CTX, "x", "user-1", "sent");
  await h.deliveryLog.record(CTX, "y", "user-1", "sent");
  const sender = new FakeSender();
  const summary = await dispatchCampaign(CTX, h.deps, campaign, [
    { userId: "user-1", token: "tok-1" },
  ], sender, SINCE);
  assertEquals(summary.capped, 1);
  assertEquals(summary.sent, 0);
  assertEquals(sender.sent.length, 0);
});

Deno.test("dispatch clears a dead token on unregistered failure", async () => {
  const h = dispatchDeps();
  const sender = new FakeSender((t) => (t === "dead" ? { ok: false, unregistered: true } : { ok: true }));
  const summary = await dispatchCampaign(CTX, h.deps, campaign, [
    { userId: "user-dead", token: "dead" },
  ], sender, SINCE);
  assertEquals(summary.failed, 1);
  assertEquals(h.cleared, ["user-dead"]);
});
