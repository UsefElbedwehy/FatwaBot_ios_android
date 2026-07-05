import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import { route } from "../functions/api/router.ts";
import { verifyAccessToken } from "../functions/api/auth/jwt.ts";
import { InMemoryConfigRepo } from "./in_memory_repo.ts";
import { InMemoryIdentityRepo } from "./in_memory_identity_repo.ts";
import { InMemoryContentRepo } from "./in_memory_content_repo.ts";

const BASE = "https://x.supabase.co/functions/v1/api";
const SECRET = "test-secret-please-rotate";

function deps() {
  return {
    repo: new InMemoryConfigRepo(),
    identity: new InMemoryIdentityRepo(),
    content: new InMemoryContentRepo(),
    jwtSecret: SECRET,
  };
}

function post(path: string, body: unknown): Request {
  return new Request(`${BASE}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

const DEVICE = { platform: "ios", app_version: "0.1.0", locale: "ar", timezone: "Asia/Riyadh" };

Deno.test("anonymous auth issues verifiable access token + refresh token", async () => {
  const d = deps();
  const res = await route(post("/v1/auth/anonymous", { device: DEVICE }), d);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.kind, "anonymous");
  assert(body.refresh_token.length > 20);
  assertEquals(body.expires_in, 3600);

  const claims = await verifyAccessToken(body.access_token, SECRET);
  assertEquals(claims?.sub, body.user_id);
  assertEquals(claims?.kind, "anonymous");
  assertEquals(d.identity.devices.size, 1);
});

Deno.test("anonymous auth validates device payload", async () => {
  const res = await route(post("/v1/auth/anonymous", { device: { platform: "windows" } }), deps());
  assertEquals(res.status, 400);
  assertEquals((await res.json()).error.code, "invalid_device");
});

Deno.test("refresh rotates and old token is single-use", async () => {
  const d = deps();
  const first = await (await route(post("/v1/auth/anonymous", { device: DEVICE }), d)).json();

  const rotated = await route(post("/v1/auth/refresh", { refresh_token: first.refresh_token }), d);
  assertEquals(rotated.status, 200);
  const second = await rotated.json();
  assertEquals(second.user_id, first.user_id);
  assertNotEquals(second.refresh_token, first.refresh_token);

  const replay = await route(post("/v1/auth/refresh", { refresh_token: first.refresh_token }), d);
  assertEquals(replay.status, 401);
});

Deno.test("refresh rejects garbage tokens", async () => {
  const res = await route(post("/v1/auth/refresh", { refresh_token: "nope" }), deps());
  assertEquals(res.status, 400);
  const res2 = await route(post("/v1/auth/refresh", { refresh_token: "x".repeat(40) }), deps());
  assertEquals(res2.status, 401);
});

Deno.test("/v1/me requires and honors bearer token", async () => {
  const d = deps();
  const anon = await (await route(post("/v1/auth/anonymous", { device: DEVICE }), d)).json();

  const unauthorized = await route(new Request(`${BASE}/v1/me`), d);
  assertEquals(unauthorized.status, 401);

  const authorized = await route(
    new Request(`${BASE}/v1/me`, { headers: { authorization: `Bearer ${anon.access_token}` } }),
    d,
  );
  assertEquals(authorized.status, 200);
  assertEquals(await authorized.json(), { user_id: anon.user_id, kind: "anonymous" });

  const tampered = await route(
    new Request(`${BASE}/v1/me`, { headers: { authorization: `Bearer ${anon.access_token}x` } }),
    d,
  );
  assertEquals(tampered.status, 401);
});
