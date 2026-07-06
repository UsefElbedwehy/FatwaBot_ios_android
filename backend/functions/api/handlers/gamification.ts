// POST /v1/gamification/events, GET /v1/gamification/profile (docs/features/gamification.md).
import { verifyAccessToken } from "../auth/jwt.ts";
import { apiError, json } from "../http.ts";
import { resolveRequired } from "../locale_resolve.ts";
import type { AppContext } from "../types.ts";
import type { AdminContentRepo } from "../admin_types.ts";
import type { GamificationRepo } from "../gamification_types.ts";
import {
  badgeEarnedAt,
  computeStreak,
  localDateBucket,
  progressForCriteria,
  type StreakDef,
} from "../gamification_engine.ts";

interface GamificationDeps {
  gamification: GamificationRepo;
  adminContent: AdminContentRepo;
  jwtSecret: string;
}

async function requireUser(req: Request, jwtSecret: string): Promise<string | Response> {
  const header = req.headers.get("authorization");
  if (!header?.startsWith("Bearer ")) return apiError(401, "unauthorized", "Valid bearer token required");
  const claims = await verifyAccessToken(header.slice("Bearer ".length), jwtSecret);
  if (!claims) return apiError(401, "unauthorized", "Valid bearer token required");
  return claims.sub;
}

interface RawEventInput {
  client_event_id?: unknown;
  event_type?: unknown;
  occurred_at?: unknown;
  timezone?: unknown;
  metadata?: unknown;
}

function isValidEvent(
  raw: RawEventInput,
): raw is Required<Pick<RawEventInput, "client_event_id" | "event_type" | "occurred_at" | "timezone">> {
  return typeof raw.client_event_id === "string" && raw.client_event_id.length > 0 &&
    typeof raw.event_type === "string" && raw.event_type.length > 0 &&
    typeof raw.occurred_at === "string" && !Number.isNaN(Date.parse(raw.occurred_at)) &&
    typeof raw.timezone === "string" && raw.timezone.length > 0;
}

/** POST /v1/gamification/events — batched, idempotent activity-event ingest. */
export async function handleSubmitEvents(
  ctx: AppContext,
  deps: GamificationDeps,
  req: Request,
  body: unknown,
): Promise<Response> {
  const userOrError = await requireUser(req, deps.jwtSecret);
  if (userOrError instanceof Response) return userOrError;

  const events = (body as { events?: unknown } | null)?.events;
  if (!Array.isArray(events) || events.length === 0) {
    return apiError(400, "invalid_body", "events must be a non-empty array");
  }
  if (!events.every((e) => isValidEvent(e as RawEventInput))) {
    return apiError(
      400,
      "invalid_event",
      "Each event needs client_event_id, event_type, occurred_at, timezone",
    );
  }

  const result = await deps.gamification.recordEvents(
    ctx,
    userOrError,
    (events as RawEventInput[]).map((e) => ({
      clientEventId: e.client_event_id as string,
      eventType: e.event_type as string,
      occurredAt: e.occurred_at as string,
      timezone: e.timezone as string,
      metadata: (e.metadata as Record<string, unknown> | undefined) ?? undefined,
    })),
  );
  return json(result);
}

function toStreakDef(fields: Record<string, unknown>): StreakDef {
  return {
    eventTypes: Array.isArray(fields.event_types) ? (fields.event_types as string[]) : [],
    requiredDailyCount: Number(fields.required_daily_count ?? 1),
    dayBoundaryType: fields.day_boundary_type === "midnight" ? "midnight" : "fixed_local_time",
    dayBoundaryLocalTime: typeof fields.day_boundary_local_time === "string"
      ? fields.day_boundary_local_time
      : "04:00",
    graceAllowance: Number(fields.grace_allowance ?? 0),
    gracePeriodDays: Number(fields.grace_period_days ?? 30),
  };
}

function isMissionActive(fields: Record<string, unknown>, now: Date): boolean {
  const startsAt = fields.starts_at as string | null | undefined;
  const endsAt = fields.ends_at as string | null | undefined;
  if (startsAt && new Date(startsAt) > now) return false;
  if (endsAt && new Date(endsAt) < now) return false;
  return true;
}

/** GET /v1/gamification/profile?timezone= — assembled streaks/missions/badges,
 * folded live from the event log + currently-published definitions. */
export async function handleGamificationProfile(
  ctx: AppContext,
  deps: GamificationDeps,
  req: Request,
  timezone: string | null,
): Promise<Response> {
  const userOrError = await requireUser(req, deps.jwtSecret);
  if (userOrError instanceof Response) return userOrError;
  const userId = userOrError;
  const tz = timezone && timezone.length > 0 ? timezone : "UTC";
  const now = new Date();

  const events = await deps.gamification.listEvents(ctx, userId);

  const [streakRows, missionRows, badgeRows] = await Promise.all([
    deps.adminContent.list(ctx, "streak-defs"),
    deps.adminContent.list(ctx, "missions"),
    deps.adminContent.list(ctx, "badges"),
  ]);

  const streaks = streakRows
    .filter((row) => row.published && row.fields.enabled !== false)
    .map((row) => {
      const def = toStreakDef(row.fields);
      const today = localDateBucket(now, tz, def);
      const result = computeStreak(events, def, today);
      return {
        key: row.fields.key,
        name: resolveRequired(row.fields.name_translations as Record<string, string>, ctx.locale),
        current_length: result.currentLength,
        longest_length: result.longestLength,
        grace_remaining: result.graceRemaining,
      };
    });

  const missions = missionRows
    .filter((row) => row.published && isMissionActive(row.fields, now))
    .map((row) => {
      const progress = progressForCriteria(events, {
        eventType: row.fields.event_type as string,
        targetCount: Number(row.fields.target_count),
        window: row.fields.progress_window as "daily" | "weekly" | "lifetime",
      }, now);
      return {
        key: row.fields.key,
        name: resolveRequired(row.fields.name_translations as Record<string, string>, ctx.locale),
        progress: progress.count,
        target: progress.target,
        window: row.fields.progress_window,
        ends_at: row.fields.ends_at ?? null,
      };
    });

  const badges = badgeRows
    .filter((row) => row.published)
    .map((row) => {
      const criteria = {
        eventType: row.fields.event_type as string,
        targetCount: Number(row.fields.target_count),
        window: row.fields.progress_window as "daily" | "weekly" | "lifetime",
      };
      const earnedAt = badgeEarnedAt(events, criteria);
      return {
        key: row.fields.key,
        name: resolveRequired(row.fields.name_translations as Record<string, string>, ctx.locale),
        icon_ref: row.fields.icon_ref,
        earned_at: earnedAt ? earnedAt.toISOString() : null,
        hiddenUntilEarned: Boolean(row.fields.hidden_until_earned),
      };
    })
    // Hidden-until-earned badges don't appear in the list at all until unlocked.
    .filter((badge) => badge.earned_at !== null || !badge.hiddenUntilEarned)
    .map(({ hiddenUntilEarned: _hiddenUntilEarned, ...badge }) => badge);

  return json({ streaks, missions, badges });
}
