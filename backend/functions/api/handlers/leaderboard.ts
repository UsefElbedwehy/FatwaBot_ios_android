// GET /v1/leaderboards, join/leave/membership, and the admin-triggered
// snapshot recompute (docs/features/leaderboard.md).
import { verifyAccessToken } from "../auth/jwt.ts";
import { apiError, json } from "../http.ts";
import { resolveRequired } from "../locale_resolve.ts";
import type { AppContext } from "../types.ts";
import type { AdminContentRepo, AdminContentRow } from "../admin_types.ts";
import type { GamificationRepo } from "../gamification_types.ts";
import type { IdentityRepo } from "../identity_types.ts";
import type { LeaderboardMembership, LeaderboardRepo, SnapshotEntry } from "../leaderboard_types.ts";
import {
  computeScore,
  type LeaderboardMetric,
  rankEntries,
  type ScoredEntry,
} from "../leaderboard_engine.ts";
import {
  type LeaderboardPeriod,
  periodBoundsFor,
  periodKeyFor,
  type Season,
  windowFor,
} from "../leaderboard_periods.ts";

interface LeaderboardDeps {
  leaderboard: LeaderboardRepo;
  gamification: GamificationRepo;
  adminContent: AdminContentRepo;
  identity: IdentityRepo;
  jwtSecret: string;
}

async function requireUser(req: Request, jwtSecret: string): Promise<string | Response> {
  const header = req.headers.get("authorization");
  if (!header?.startsWith("Bearer ")) return apiError(401, "unauthorized", "Valid bearer token required");
  const claims = await verifyAccessToken(header.slice("Bearer ".length), jwtSecret);
  if (!claims) return apiError(401, "unauthorized", "Valid bearer token required");
  return claims.sub;
}

function seasonOf(fields: Record<string, unknown>): Season {
  return {
    startsAt: fields.season_starts_at ? new Date(fields.season_starts_at as string) : null,
    endsAt: fields.season_ends_at ? new Date(fields.season_ends_at as string) : null,
  };
}

function metricOf(fields: Record<string, unknown>): LeaderboardMetric {
  const raw = (fields.metric as { terms?: unknown } | undefined)?.terms;
  if (!Array.isArray(raw)) return { terms: [] };
  return {
    terms: raw.map((t) => ({
      eventType: (t as { event_type: string }).event_type,
      weight: Number((t as { weight: number }).weight),
      capPerPeriod: Number((t as { cap_per_period: number }).cap_per_period),
    })),
  };
}

async function findDefByKey(
  deps: LeaderboardDeps,
  ctx: AppContext,
  key: string,
): Promise<AdminContentRow | null> {
  const rows = await deps.adminContent.list(ctx, "leaderboard-defs");
  return rows.find((r) => r.published && r.fields.enabled !== false && r.fields.key === key) ?? null;
}

/** Same lookup, but for the admin standings view — which must still show a
 * board an admin unpublished (retired or paused, `consistency_city`-style),
 * since "what were the final standings" doesn't stop being a real question
 * just because the board is no longer live for users. */
async function findAnyDefByKey(
  deps: LeaderboardDeps,
  ctx: AppContext,
  key: string,
): Promise<AdminContentRow | null> {
  const rows = await deps.adminContent.list(ctx, "leaderboard-defs");
  return rows.find((r) => r.fields.key === key) ?? null;
}

/**
 * Which peer group a member is ranked inside.
 *
 * This is what makes `scope` mean anything: without it, recompute ranks every
 * member of a board together, so a "city" board ranks a user in Cairo against
 * one in Jakarta and a "country" board is just the global board renamed.
 *
 * A member whose region is unknown falls into the empty bucket. On a global
 * board that is everyone, which is correct. On a regional board it means they
 * are ranked only against others who also declined to share a region — never
 * silently folded into someone else's city.
 */
export function bucketFor(
  scope: string,
  membership: { city: string | null; country: string | null },
): string {
  switch (scope) {
    case "city":
      return membership.city?.trim() ?? "";
    case "country":
      return membership.country?.trim().toUpperCase() ?? "";
    default:
      return "";
  }
}

/** GET /v1/leaderboards — every published+enabled board, with my_rank and a
 * ranked entry list from the last recomputed snapshot. */
export async function handleListLeaderboards(
  ctx: AppContext,
  deps: LeaderboardDeps,
  req: Request,
): Promise<Response> {
  const userOrError = await requireUser(req, deps.jwtSecret);
  if (userOrError instanceof Response) return userOrError;
  const userId = userOrError;
  const now = new Date();

  const defs = (await deps.adminContent.list(ctx, "leaderboard-defs")).filter((r) =>
    r.published && r.fields.enabled !== false
  );

  const boards = await Promise.all(defs.map(async (row) => {
    const period = row.fields.period as LeaderboardPeriod;
    const periodKey = periodKeyFor(period, now, seasonOf(row.fields));
    // Refresh before reading if this period's snapshot is missing or has aged
    // out (see SNAPSHOT_MAX_AGE_MS). Without this the board only ever changes
    // when an admin manually triggers a recompute.
    const computedAt = await deps.leaderboard.snapshotComputedAt(ctx, row.fields.key as string, periodKey);
    if (computedAt === null || now.getTime() - computedAt.getTime() > SNAPSHOT_MAX_AGE_MS) {
      // A failure here must not take the whole screen down: stale or empty
      // standings are far better than an error where the leaderboard should be.
      try {
        await recomputeSnapshotFor(ctx, deps, row);
      } catch {
        // fall through and serve whatever was last materialized
      }
    }
    const [snapshot, memberships, myMembership] = await Promise.all([
      deps.leaderboard.getSnapshot(ctx, row.fields.key as string, periodKey),
      deps.leaderboard.listMemberships(ctx, row.fields.key as string),
      deps.leaderboard.getMembership(ctx, row.fields.key as string, userId),
    ]);
    const membershipByUser = new Map(memberships.map((m) => [m.userId, m]));
    // A board is only "local" if the user sees their own region, not the whole
    // table. Non-members see the empty bucket — which on a global board is the
    // real standings, and on a regional board is the honest answer: nothing to
    // show until you join and say where you are.
    const scope = String(row.fields.scope ?? "global");
    const myBucket = myMembership ? bucketFor(scope, myMembership) : "";
    const visible = snapshot.filter((s) => s.bucket === myBucket);
    const requiresPublishedName = Boolean(
      (row.fields.display_requirements as { requires_published_name?: boolean } | undefined)
        ?.requires_published_name,
    );

    const entries = await Promise.all(visible.map(async (s) => {
      const membership = membershipByUser.get(s.userId);
      const shouldPublishName = requiresPublishedName || Boolean(membership?.publishName);
      const displayName = shouldPublishName
        ? (await deps.identity.getProfile(s.userId))?.displayName ?? null
        : null;
      return {
        rank: s.rank,
        score: s.score,
        display_name: displayName ?? membership?.handle ?? "unknown",
      };
    }));

    const myRank = visible.find((s) => s.userId === userId)?.rank ?? null;
    const bounds = periodBoundsFor(period, now, seasonOf(row.fields));

    return {
      key: row.fields.key,
      name: resolveRequired(row.fields.name_translations as Record<string, string>, ctx.locale),
      scope: row.fields.scope,
      period: row.fields.period,
      // null for `lifetime` (no reset), and for `seasonal`/`challenge` boards
      // an admin hasn't dated yet — clients treat a missing end as "no
      // countdown to show", not an error.
      period_starts_at: bounds.start?.toISOString() ?? null,
      period_ends_at: bounds.end?.toISOString() ?? null,
      joined: myMembership !== null,
      my_rank: myRank,
      entries,
    };
  }));

  return json({ boards });
}

interface JoinBody {
  publish_name?: unknown;
  city?: unknown;
  country?: unknown;
}

/** POST /v1/leaderboards/{key}/join */
export async function handleJoinLeaderboard(
  ctx: AppContext,
  deps: LeaderboardDeps,
  req: Request,
  key: string,
  body: unknown,
): Promise<Response> {
  const userOrError = await requireUser(req, deps.jwtSecret);
  if (userOrError instanceof Response) return userOrError;
  const userId = userOrError;

  const def = await findDefByKey(deps, ctx, key);
  if (!def) return apiError(404, "unknown_leaderboard", `No published leaderboard '${key}'`);

  const b = (body as JoinBody | null) ?? {};
  const publishName = b.publish_name === true;
  const city = typeof b.city === "string" ? b.city : null;
  const country = typeof b.country === "string" ? b.country.trim().toUpperCase() : null;

  if (def.fields.scope === "city" && !city) {
    return apiError(400, "city_required", "city-scope boards require an explicit city (Q2c: opt-in only)");
  }
  if (def.fields.scope === "country" && !country) {
    return apiError(
      400,
      "country_required",
      "country-scope boards require an explicit country (opt-in only)",
    );
  }

  const membership = await deps.leaderboard.join(
    ctx,
    key,
    userId,
    publishName,
    def.fields.scope === "city" ? city : null,
    // Same opt-in rule as city: captured only by the board that needs it.
    def.fields.scope === "country" ? country : null,
  );
  return json(toMembershipJson(membership));
}

/** POST /v1/leaderboards/{key}/leave */
export async function handleLeaveLeaderboard(
  ctx: AppContext,
  deps: LeaderboardDeps,
  req: Request,
  key: string,
): Promise<Response> {
  const userOrError = await requireUser(req, deps.jwtSecret);
  if (userOrError instanceof Response) return userOrError;
  await deps.leaderboard.leave(ctx, key, userOrError);
  return json({ left: true });
}

interface MembershipPatchBody {
  publish_name?: unknown;
  city?: unknown;
  country?: unknown;
}

/** PATCH /v1/leaderboards/{key}/membership */
export async function handleUpdateMembership(
  ctx: AppContext,
  deps: LeaderboardDeps,
  req: Request,
  key: string,
  body: unknown,
): Promise<Response> {
  const userOrError = await requireUser(req, deps.jwtSecret);
  if (userOrError instanceof Response) return userOrError;
  const userId = userOrError;

  const b = (body as MembershipPatchBody | null) ?? {};
  const changes: { publishName?: boolean; city?: string | null; country?: string | null } = {};
  if (typeof b.publish_name === "boolean") changes.publishName = b.publish_name;
  if (b.city === null || typeof b.city === "string") changes.city = b.city;
  if (b.country === null) changes.country = null;
  else if (typeof b.country === "string") changes.country = b.country.trim().toUpperCase();

  const updated = await deps.leaderboard.updateMembership(ctx, key, userId, changes);
  if (!updated) return apiError(404, "not_a_member", "You haven't joined this leaderboard yet");
  return json(toMembershipJson(updated));
}

function toMembershipJson(m: LeaderboardMembership) {
  return { handle: m.handle, publish_name: m.publishName, city: m.city, country: m.country };
}

/** POST /admin/v1/leaderboards/{key}/recompute — materializes the current
 * period's snapshot. Stands in for a pg_cron-scheduled job (not available
 * until Supabase is deployed); admins can trigger it on demand meanwhile. */
export async function handleRecomputeSnapshot(
  ctx: AppContext,
  deps: LeaderboardDeps,
  key: string,
): Promise<Response> {
  const def = await findDefByKey(deps, ctx, key);
  if (!def) return apiError(404, "unknown_leaderboard", `No published leaderboard '${key}'`);
  return json(await recomputeSnapshotFor(ctx, deps, def));
}

/**
 * GET /admin/v1/leaderboards/{key}/standings?period_key=... — every ranked
 * entry, unfiltered by bucket, so an admin can find the winner: the true
 * global #1, or #1 in any single country, not just their own.
 *
 * Defaults to the *current* period (recomputing first if it looks stale, the
 * same freshness rule `handleListLeaderboards` applies) when no `period_key`
 * is given. An explicit `period_key` is served as stored — recomputing a past
 * period would mean re-deriving it from today's `now`, which is not what "the
 * final standings for last half" means once that half is over.
 */
export async function handleGetStandings(
  ctx: AppContext,
  deps: LeaderboardDeps,
  key: string,
  periodKey: string | null,
): Promise<Response> {
  const def = await findAnyDefByKey(deps, ctx, key);
  if (!def) return apiError(404, "unknown_leaderboard", `No leaderboard '${key}'`);

  const now = new Date();
  const period = def.fields.period as LeaderboardPeriod;
  const currentPeriodKey = periodKeyFor(period, now, seasonOf(def.fields));
  const resolvedPeriodKey = periodKey ?? currentPeriodKey;

  if (resolvedPeriodKey === currentPeriodKey) {
    const computedAt = await deps.leaderboard.snapshotComputedAt(ctx, key, currentPeriodKey);
    if (computedAt === null || now.getTime() - computedAt.getTime() > SNAPSHOT_MAX_AGE_MS) {
      try {
        await recomputeSnapshotFor(ctx, deps, def);
      } catch {
        // Serve whatever was last materialized rather than fail the page.
      }
    }
  }

  const [snapshot, memberships] = await Promise.all([
    deps.leaderboard.getSnapshot(ctx, key, resolvedPeriodKey),
    deps.leaderboard.listMemberships(ctx, key),
  ]);
  const membershipByUser = new Map(memberships.map((m) => [m.userId, m]));

  const entries = await Promise.all(
    snapshot.map(async (s) => {
      const membership = membershipByUser.get(s.userId);
      const profile = await deps.identity.getProfile(s.userId);
      return {
        rank: s.rank,
        score: s.score,
        bucket: s.bucket,
        country: membership?.country ?? null,
        city: membership?.city ?? null,
        // The admin view is not bound by a member's publish_name choice —
        // that setting controls what *other users* see, not the operator
        // who is about to hand them a prize and needs to know who they are.
        display_name: profile?.displayName ?? membership?.handle ?? "unknown",
      };
    }),
  );

  return json({
    key,
    period: def.fields.period,
    period_key: resolvedPeriodKey,
    is_current_period: resolvedPeriodKey === currentPeriodKey,
    entries,
  });
}

/** GET /admin/v1/leaderboards/{key}/periods — every period this board has
 * ever had standings for, newest first, so the admin view can offer "see a
 * past period" (e.g. last half's final winner) as a simple picker. */
export async function handleListStandingsPeriods(
  ctx: AppContext,
  deps: LeaderboardDeps,
  key: string,
): Promise<Response> {
  const def = await findAnyDefByKey(deps, ctx, key);
  if (!def) return apiError(404, "unknown_leaderboard", `No leaderboard '${key}'`);
  const periods = await deps.leaderboard.listPeriodKeys(ctx, key);
  return json({ periods });
}

/**
 * How long a materialized snapshot is served before the next read refreshes it.
 *
 * ## Why staleness-triggered rather than a scheduler
 * Recompute had exactly one trigger: an admin POSTing it by hand. Nothing else
 * called it — no pg_cron job exists — so a freshly seeded board would have
 * shown empty standings forever, and a board that *was* computed would have
 * frozen at whatever moment an admin last remembered to press the button. The
 * feature would have looked broken for reasons no user could act on.
 *
 * Refreshing on read when the snapshot has aged past this bounds the work to
 * once per window per board no matter how many clients ask, needs no external
 * scheduler, and cannot leave the board permanently stale. Concurrent readers
 * may both recompute; the snapshot upsert is keyed on
 * (app, board, period, user), so the loser overwrites with the same numbers
 * rather than corrupting anything.
 */
const SNAPSHOT_MAX_AGE_MS = 10 * 60 * 1000;

export async function recomputeSnapshotFor(
  ctx: AppContext,
  deps: LeaderboardDeps,
  def: AdminContentRow,
): Promise<{ period_key: string; entries: number; buckets: number }> {
  const key = def.fields.key as string;
  const period = def.fields.period as LeaderboardPeriod;
  const season = seasonOf(def.fields);
  const now = new Date();
  const periodKey = periodKeyFor(period, now, season);
  const window = windowFor(period, now, season);
  const metric = metricOf(def.fields);
  const tieBreakers = Array.isArray(def.fields.tie_breakers) ? (def.fields.tie_breakers as string[]) : [];

  const memberships = await deps.leaderboard.listMemberships(ctx, key);
  if (memberships.length === 0) {
    await deps.leaderboard.saveSnapshot(ctx, key, periodKey, []);
    return { period_key: periodKey, entries: 0, buckets: 0 };
  }

  const eventsByUser = await deps.gamification.listEventsForUsers(ctx, memberships.map((m) => m.userId));
  const scope = String(def.fields.scope ?? "global");

  const scoreOf = (userId: string): ScoredEntry => {
    const events = eventsByUser[userId] ?? [];
    const score = computeScore(events, metric, window.start, window.end);
    const tieBreakValues = tieBreakers.map((eventType) =>
      events.filter((e) =>
        e.eventType === eventType && (!window.start || e.occurredAt >= window.start) &&
        (!window.end || e.occurredAt <= window.end)
      ).length
    );
    return { userId, score, tieBreakValues };
  };

  // Rank *within* each region, not across all of them. Ranking globally and
  // filtering afterwards would leave a city board reading "rank 4,812 of your
  // city" — the number would be a global rank wearing a local label.
  const byBucket = new Map<string, ScoredEntry[]>();
  for (const m of memberships) {
    const bucket = bucketFor(scope, m);
    const group = byBucket.get(bucket) ?? [];
    group.push(scoreOf(m.userId));
    byBucket.set(bucket, group);
  }

  const entries: SnapshotEntry[] = [];
  for (const [bucket, group] of byBucket) {
    for (const r of rankEntries(group)) {
      entries.push({ userId: r.userId, rank: r.rank, score: r.score, bucket });
    }
  }

  await deps.leaderboard.saveSnapshot(ctx, key, periodKey, entries);
  return { period_key: periodKey, entries: entries.length, buckets: byBucket.size };
}
