import type { AppContext } from "./types.ts";

export const PRIMARY_APP_ID = "00000000-0000-4000-a000-000000000001";

/** Resolve the app-scoped request context (ADR-0015). Single app today:
 *  app_id is fixed; platform/version/locale come from client headers. */
export function resolveContext(req: Request): AppContext {
  const platformHeader = req.headers.get("x-client-platform")?.toLowerCase();
  const platform = platformHeader === "ios" || platformHeader === "android" ? platformHeader : "all";
  return {
    appId: PRIMARY_APP_ID,
    platform,
    appVersion: req.headers.get("x-client-version"),
    locale: req.headers.get("x-client-locale") ?? "ar",
  };
}
