import { apiError, json } from "../http.ts";
import type { AppContext, ConfigRepo } from "../types.ts";

const CACHE_SHORT = { "cache-control": "public, max-age=300" };

/** GET /v1/config — remote config + flags + enabled locales in one payload. */
export async function handleConfig(ctx: AppContext, repo: ConfigRepo): Promise<Response> {
  const [entries, flags, locales] = await Promise.all([
    repo.remoteConfig(ctx),
    repo.featureFlags(ctx),
    repo.enabledLocales(ctx),
  ]);
  return json(
    {
      config: Object.fromEntries(entries.map((e) => [e.key, e.value])),
      flags: Object.fromEntries(flags.map((f) => [f.key, { enabled: f.enabled, rollout: f.rollout }])),
      locales,
    },
    200,
    CACHE_SHORT,
  );
}

/** GET /v1/config/theme — published theme tokens. */
export async function handleTheme(ctx: AppContext, repo: ConfigRepo): Promise<Response> {
  const theme = await repo.publishedTheme(ctx);
  if (!theme) return apiError(404, "no_published_theme", "No published theme");
  return json(theme, 200, CACHE_SHORT);
}

/** GET /v1/config/strings/{locale}?since_version= — delta-aware string pack. */
export async function handleStringPack(
  ctx: AppContext,
  repo: ConfigRepo,
  locale: string,
  sinceVersion: number | null,
): Promise<Response> {
  if (sinceVersion !== null && !Number.isInteger(sinceVersion)) {
    return apiError(400, "invalid_since_version", "since_version must be an integer");
  }
  const pack = await repo.publishedStringPack(ctx, locale, sinceVersion);
  if (!pack) return json({ up_to_date: true }, 200, CACHE_SHORT);
  return json(pack, 200, CACHE_SHORT);
}

/** GET /v1/home — published Home layout for the caller's platform. */
export async function handleHomeLayout(ctx: AppContext, repo: ConfigRepo): Promise<Response> {
  const layout = await repo.publishedHomeLayout(ctx);
  if (!layout) return apiError(404, "no_published_layout", "No published home layout");
  return json(layout, 200, CACHE_SHORT);
}

/** GET /v1/config/prayer-defaults?country=SA — falls back to '*' defaults. */
export async function handlePrayerDefaults(
  ctx: AppContext,
  repo: ConfigRepo,
  country: string,
): Promise<Response> {
  const normalized = country.toUpperCase();
  if (normalized !== "*" && !/^[A-Z]{2}$/.test(normalized)) {
    return apiError(400, "invalid_country", "country must be an ISO 3166-1 alpha-2 code");
  }
  const defaults = await repo.prayerDefaults(ctx, normalized);
  return json(defaults, 200, CACHE_SHORT);
}
