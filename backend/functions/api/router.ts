// Pure router: no Deno/Supabase globals so it is unit-testable.
// The gateway function is served at /functions/v1/api on Supabase; clients call
// paths like /functions/v1/api/v1/health. Routing happens on the "/v1/..." suffix.

import { apiError, internalError, json, methodNotAllowed, notFound } from "./http.ts";
import { resolveContext } from "./context.ts";
import { verifyAccessToken } from "./auth/jwt.ts";
import type { ConfigRepo } from "./types.ts";
import type { IdentityRepo } from "./identity_types.ts";
import { handleAnonymousAuth, handleRefresh } from "./handlers/auth.ts";
import {
  handleConfig,
  handleHomeLayout,
  handlePrayerDefaults,
  handleStringPack,
  handleTheme,
} from "./handlers/config.ts";

export interface Deps {
  repo: ConfigRepo;
  identity: IdentityRepo;
  jwtSecret: string;
}

/** Extracts the API path suffix beginning at the last "/v1/" — the Supabase
 *  function mount itself lives under "/functions/v1/", so the first match is
 *  the platform prefix, not our API version. */
export function apiPath(pathname: string): string | null {
  const marker = "/api/v1/";
  const mounted = pathname.indexOf(marker);
  if (mounted !== -1) return pathname.slice(mounted + marker.length - "/v1/".length);
  return pathname.startsWith("/v1/") ? pathname : null;
}

async function readBody(req: Request): Promise<unknown | undefined> {
  try {
    return await req.json();
  } catch {
    return undefined;
  }
}

export async function route(req: Request, deps: Deps): Promise<Response> {
  const url = new URL(req.url);
  const path = apiPath(url.pathname);
  if (path === null) return notFound();

  const ctx = resolveContext(req);
  const method = req.method;
  try {
    // --- public reads ---
    if (method === "GET") {
      switch (path) {
        case "/v1/health":
          return json({ status: "ok", version: "v1" });
        case "/v1/config":
          return await handleConfig(ctx, deps.repo);
        case "/v1/config/theme":
          return await handleTheme(ctx, deps.repo);
        case "/v1/home":
          return await handleHomeLayout(ctx, deps.repo);
        case "/v1/config/prayer-defaults":
          return await handlePrayerDefaults(ctx, deps.repo, url.searchParams.get("country") ?? "*");
      }
      const stringsMatch = path.match(/^\/v1\/config\/strings\/([A-Za-z0-9-]{2,20})$/);
      if (stringsMatch) {
        const since = url.searchParams.get("since_version");
        return await handleStringPack(ctx, deps.repo, stringsMatch[1], since ? Number(since) : null);
      }
      // --- authenticated reads ---
      if (path === "/v1/me") {
        const claims = await authenticate(req, deps.jwtSecret);
        if (!claims) return apiError(401, "unauthorized", "Valid bearer token required");
        return json({ user_id: claims.sub, kind: claims.kind });
      }
      return notFound();
    }

    // --- auth writes ---
    if (method === "POST") {
      switch (path) {
        case "/v1/auth/anonymous":
          return await handleAnonymousAuth(ctx, deps, await readBody(req));
        case "/v1/auth/refresh":
          return await handleRefresh(ctx, deps, await readBody(req));
      }
      return notFound();
    }

    return methodNotAllowed();
  } catch (err) {
    return internalError(err);
  }
}

async function authenticate(req: Request, secret: string) {
  const header = req.headers.get("authorization");
  if (!header?.startsWith("Bearer ")) return null;
  return await verifyAccessToken(header.slice("Bearer ".length), secret);
}
