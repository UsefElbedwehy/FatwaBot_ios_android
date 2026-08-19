// POST /v1/analytics/events — first-party product-analytics ingest
// (docs/features/analytics-and-crash-reporting.md).
//
// Separate from /v1/gamification/events on purpose: that endpoint feeds
// gamification.activity_events, which is folded per user on every profile read.
// See migration 0023 for the storage rationale and the privacy contract.
import { verifyAccessToken } from "../auth/jwt.ts";
import { apiError, json } from "../http.ts";
import type { AppContext } from "../types.ts";
import type { AnalyticsEventInput, AnalyticsRepo } from "../analytics_types.ts";

interface AnalyticsDeps {
  analytics: AnalyticsRepo;
  jwtSecret: string;
}

/** A client that batches more than this is misbehaving; the whole request is
 * refused so the client backs off rather than silently losing the tail. */
const MAX_BATCH = 100;
const MAX_NAME_LEN = 64;
const MAX_APP_VERSION_LEN = 32;
const MAX_PARAM_KEYS = 10;
const MAX_PARAM_VALUE_LEN = 100;

/** Last line of defence for the privacy contract: analytics carries screen
 * names, stable keys and counts — never what the user typed, where they are, or
 * who they are. If a future client bug starts attaching any of these keys the
 * server drops the event instead of storing it. Matched case-insensitively on
 * the exact key; the offending VALUE is never logged. */
const FORBIDDEN_PARAM_KEYS = new Set([
  "query",
  "q",
  "search",
  "search_query",
  "text",
  "body",
  "content",
  "lat",
  "latitude",
  "lng",
  "longitude",
  "location",
  "city",
  "coords",
  "name",
  "display_name",
  "email",
  "phone",
  "token",
  "push_token",
  "user_id",
]);

async function requireUser(req: Request, jwtSecret: string): Promise<string | Response> {
  const header = req.headers.get("authorization");
  if (!header?.startsWith("Bearer ")) return apiError(401, "unauthorized", "Valid bearer token required");
  const claims = await verifyAccessToken(header.slice("Bearer ".length), jwtSecret);
  if (!claims) return apiError(401, "unauthorized", "Valid bearer token required");
  return claims.sub;
}

interface RawAnalyticsEvent {
  client_event_id?: unknown;
  name?: unknown;
  occurred_at?: unknown;
  platform?: unknown;
  app_version?: unknown;
  params?: unknown;
}

/** Coerces one params object to a flat string map, or null if it violates the
 * shape limits or the privacy contract. Values are stringified (clients legally
 * send numbers/booleans) and truncated rather than rejected — a long value is a
 * sloppy client, not a reason to lose the event. */
function normalizeParams(raw: unknown): Record<string, string> | null {
  if (raw === undefined || raw === null) return {};
  if (typeof raw !== "object" || Array.isArray(raw)) return null;
  const entries = Object.entries(raw as Record<string, unknown>);
  if (entries.length > MAX_PARAM_KEYS) return null;
  const out: Record<string, string> = {};
  for (const [key, value] of entries) {
    if (FORBIDDEN_PARAM_KEYS.has(key.toLowerCase())) return null;
    const text = String(value);
    // Reject rather than truncate. Legitimate params are short stable keys
    // (screen names, routes, counts) — nothing real approaches this limit, so an
    // oversized value means a client is sending free text under an allowed key,
    // which is exactly what this guard exists to refuse. Truncating would
    // silently persist the first 100 characters of what might be a user's
    // question; dropping the event loses nothing that mattered.
    if (text.length > MAX_PARAM_VALUE_LEN) return null;
    out[key] = text;
  }
  return out;
}

/** One invalid event is skipped and counted in `rejected` — it must never fail
 * the batch, or a single bad event would drop every good one alongside it. */
function normalizeEvent(raw: RawAnalyticsEvent): AnalyticsEventInput | null {
  if (typeof raw.client_event_id !== "string" || raw.client_event_id.length === 0) return null;
  if (typeof raw.name !== "string" || raw.name.length === 0 || raw.name.length > MAX_NAME_LEN) return null;
  if (typeof raw.occurred_at !== "string" || Number.isNaN(Date.parse(raw.occurred_at))) return null;
  if (raw.platform !== undefined && raw.platform !== "ios" && raw.platform !== "android") return null;
  if (
    raw.app_version !== undefined &&
    (typeof raw.app_version !== "string" || raw.app_version.length > MAX_APP_VERSION_LEN)
  ) {
    return null;
  }
  const params = normalizeParams(raw.params);
  if (params === null) return null;

  return {
    clientEventId: raw.client_event_id,
    name: raw.name,
    occurredAt: raw.occurred_at,
    platform: raw.platform as "ios" | "android" | undefined,
    appVersion: raw.app_version as string | undefined,
    params,
  };
}

/** POST /v1/analytics/events — batched, idempotent, privacy-screened ingest. */
export async function handleSubmitAnalyticsEvents(
  ctx: AppContext,
  deps: AnalyticsDeps,
  req: Request,
  body: unknown,
): Promise<Response> {
  const userOrError = await requireUser(req, deps.jwtSecret);
  if (userOrError instanceof Response) return userOrError;

  const events = (body as { events?: unknown } | null)?.events;
  if (!Array.isArray(events) || events.length === 0) {
    return apiError(400, "invalid_body", "events must be a non-empty array");
  }
  if (events.length > MAX_BATCH) {
    return apiError(400, "invalid_body", `events must contain at most ${MAX_BATCH} entries`);
  }

  const valid: AnalyticsEventInput[] = [];
  let rejected = 0;
  for (const raw of events as RawAnalyticsEvent[]) {
    const normalized = normalizeEvent(raw ?? {});
    if (normalized === null) rejected += 1;
    else valid.push(normalized);
  }

  const { accepted, duplicates } = await deps.analytics.recordEvents(ctx, userOrError, valid);
  return json({ accepted, duplicates, rejected });
}
