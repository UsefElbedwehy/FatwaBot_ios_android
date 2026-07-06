import { assertEquals } from "jsr:@std/assert@1";
import { apiPath, route } from "../functions/api/router.ts";
import { InMemoryConfigRepo } from "./in_memory_repo.ts";
import { InMemoryIdentityRepo } from "./in_memory_identity_repo.ts";
import { InMemoryContentRepo } from "./in_memory_content_repo.ts";
import {
  InMemoryAdminAuthRepo,
  InMemoryAdminContentRepo,
  InMemoryAuditLogRepo,
} from "./in_memory_admin_repo.ts";
import { DevIdentityProviderVerifier } from "../functions/api/auth/provider_verify.ts";

const BASE = "https://x.supabase.co/functions/v1/api";

function get(path: string, headers: HeadersInit = {}): Request {
  return new Request(`${BASE}${path}`, { headers });
}

function deps() {
  return {
    repo: new InMemoryConfigRepo(),
    identity: new InMemoryIdentityRepo(),
    content: new InMemoryContentRepo(),
    adminContent: new InMemoryAdminContentRepo(),
    adminAuth: new InMemoryAdminAuthRepo(),
    auditLog: new InMemoryAuditLogRepo(),
    jwtSecret: "test-secret",
    verifier: new DevIdentityProviderVerifier(),
  };
}

Deno.test("apiPath extracts /v1 suffix from function-prefixed paths", () => {
  assertEquals(apiPath("/functions/v1/api/v1/health"), "/v1/health");
  assertEquals(apiPath("/api/v1/config/theme"), "/v1/config/theme");
  assertEquals(apiPath("/no-version-here"), null);
});

Deno.test("apiPath extracts /admin/v1 suffix (ADR-0009 dashboard surface)", () => {
  assertEquals(apiPath("/functions/v1/api/admin/v1/auth/login"), "/admin/v1/auth/login");
  assertEquals(apiPath("/api/admin/v1/content/azkar-categories"), "/admin/v1/content/azkar-categories");
});

Deno.test("GET /v1/health returns ok", async () => {
  const res = await route(get("/v1/health"), deps());
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { status: "ok", version: "v1" });
});

Deno.test("GET /v1/config aggregates config, flags, locales", async () => {
  const res = await route(get("/v1/config"), deps());
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.config["hijri.default_offset_days"], 0);
  assertEquals(body.flags["module.prayer"].enabled, true);
  assertEquals(body.flags["module.ai_ask"].enabled, false);
  assertEquals(body.locales.length, 2);
  assertEquals(body.locales[0].direction, "rtl");
});

Deno.test("GET /v1/config/theme returns published theme", async () => {
  const res = await route(get("/v1/config/theme"), deps());
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.version, 1);
});

Deno.test("GET /v1/config/theme 404s when nothing published", async () => {
  const d = deps();
  d.repo.theme = null;
  const res = await route(get("/v1/config/theme"), d);
  assertEquals(res.status, 404);
  assertEquals((await res.json()).error.code, "no_published_theme");
});

Deno.test("GET /v1/config/strings/ar returns latest pack", async () => {
  const res = await route(get("/v1/config/strings/ar"), deps());
  const body = await res.json();
  assertEquals(body.version, 3);
  assertEquals(body.strings["home.ask.placeholder"], "ما حكم...؟");
});

Deno.test("GET /v1/config/strings/ar?since_version=3 reports up to date", async () => {
  const res = await route(get("/v1/config/strings/ar?since_version=3"), deps());
  assertEquals(await res.json(), { up_to_date: true });
});

Deno.test("GET /v1/config/strings rejects bad since_version", async () => {
  const res = await route(get("/v1/config/strings/ar?since_version=abc"), deps());
  assertEquals(res.status, 400);
});

Deno.test("GET /v1/home returns sections in order", async () => {
  const res = await route(get("/v1/home", { "x-client-platform": "ios" }), deps());
  const body = await res.json();
  assertEquals(body.sections.map((s: { type: string }) => s.type), ["prayer_hero", "ask_ai"]);
});

Deno.test("GET /v1/config/prayer-defaults falls back to global", async () => {
  const specific = await (await route(get("/v1/config/prayer-defaults?country=sa"), deps())).json();
  assertEquals(specific.method, "umm_al_qura");
  const fallback = await (await route(get("/v1/config/prayer-defaults?country=FR"), deps())).json();
  assertEquals(fallback.method, "mwl");
  const bad = await route(get("/v1/config/prayer-defaults?country=xyz"), deps());
  assertEquals(bad.status, 400);
});

Deno.test("unknown routes 404; unsupported methods 405", async () => {
  assertEquals((await route(get("/v1/nope"), deps())).status, 404);
  const postUnknown = await route(new Request(`${BASE}/v1/config`, { method: "POST" }), deps());
  assertEquals(postUnknown.status, 404, "POST to a GET-only path is an unknown route");
  const put = await route(new Request(`${BASE}/v1/config`, { method: "PUT" }), deps());
  assertEquals(put.status, 405);
});
