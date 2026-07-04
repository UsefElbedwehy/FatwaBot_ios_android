// Pure router: no Deno/Supabase globals so it is unit-testable.
// The gateway function is served at /functions/v1/api on Supabase; clients call
// paths like /functions/v1/api/v1/health. Routing happens on the "/v1/..." suffix.

import { internalError, json, methodNotAllowed, notFound } from "./http.ts";
import { resolveContext } from "./context.ts";
import type { ConfigRepo } from "./types.ts";
import {
  handleConfig,
  handleHomeLayout,
  handlePrayerDefaults,
  handleStringPack,
  handleTheme,
} from "./handlers/config.ts";

export interface Deps {
  repo: ConfigRepo;
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

export async function route(req: Request, deps: Deps): Promise<Response> {
  const url = new URL(req.url);
  const path = apiPath(url.pathname);
  if (path === null) return notFound();
  if (req.method !== "GET") return methodNotAllowed(); // M0: read-only surface

  const ctx = resolveContext(req);
  try {
    if (path === "/v1/health") {
      return json({ status: "ok", version: "v1" });
    }
    if (path === "/v1/config") {
      return await handleConfig(ctx, deps.repo);
    }
    if (path === "/v1/config/theme") {
      return await handleTheme(ctx, deps.repo);
    }
    if (path === "/v1/home") {
      return await handleHomeLayout(ctx, deps.repo);
    }
    if (path === "/v1/config/prayer-defaults") {
      return await handlePrayerDefaults(ctx, deps.repo, url.searchParams.get("country") ?? "*");
    }
    const stringsMatch = path.match(/^\/v1\/config\/strings\/([A-Za-z0-9-]{2,20})$/);
    if (stringsMatch) {
      const since = url.searchParams.get("since_version");
      return await handleStringPack(ctx, deps.repo, stringsMatch[1], since ? Number(since) : null);
    }
    return notFound();
  } catch (err) {
    return internalError(err);
  }
}
