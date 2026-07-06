// GET /v1/leaderboards, join/leave/membership, and the admin-triggered
// snapshot recompute (docs/features/leaderboard.md).
import { verifyAccessToken } from "../auth/jwt.ts";
import { apiError, json } from "../http.ts";
import { resolveRequired } from "../locale_resolve.ts";
import type { AppContext } from "../types.ts";
import type { AdminContentRepo, AdminContentRow } from "../admin_types.ts";
import type { GamificationRepo } from "../gamification_types.ts";
import type { IdentityRepo } from "../identity_types.ts";
import type { LeaderboardMembership, LeaderboardRepo } from "../leaderboard_types.ts";
import {
  computeScore,
  type LeaderboardMetric,
  rankEntries,
  type ScoredEntry,
} from "../leaderboard_engine.ts";
import { type LeaderboardPeriod, periodKeyFor, type Season, windowFor } from "../leaderboard_periods.ts";

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
    const [snapshot, memberships, myMembership] = await Promise.all([
      deps.leaderboard.getSnapshot(ctx, row.fields.key as string, periodKey),
      deps.leaderboard.listMemberships(ctx, row.fields.key as string),
      deps.leaderboard.getMembership(ctx, row.fields.key as string, userId),
    ]);
    const membershipByUser = new Map(memberships.map((m) => [m.userId, m]));
    const requiresPublishedName = Boolean(
      (row.fields.display_requirements as { requires_published_name?: boolean } | undefined)
        ?.requires_published_name,
    );

    const entries = await Promise.all(snapshot.map(async (s) => {
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

    const myRank = snapshot.find((s) => s.userId === userId)?.rank ?? null;

    return {
      key: row.fields.key,
      name: resolveRequired(row.fields.name_translations as Record<string, string>, ctx.locale),
      scope: row.fields.scope,
      period: row.fields.period,
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

  if (def.fields.scope === "city" && !city) {
    return apiError(400, "city_required", "city-scope boards require an explicit city (Q2c: opt-in only)");
  }

  const membership = await deps.leaderboard.join(
    ctx,
    key,
    userId,
    publishName,
    def.fields.scope === "city" ? city : null,
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
  const changes: { publishName?: boolean; city?: string | null } = {};
  if (typeof b.publish_name === "boolean") changes.publishName = b.publish_name;
  if (b.city === null || typeof b.city === "string") changes.city = b.city;

  const updated = await deps.leaderboard.updateMembership(ctx, key, userId, changes);
  if (!updated) return apiError(404, "not_a_member", "You haven't joined this leaderboard yet");
  return json(toMembershipJson(updated));
}

function toMembershipJson(m: LeaderboardMembership) {
  return { handle: m.handle, publish_name: m.publishName, city: m.city };
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
    return json({ period_key: periodKey, entries: 0 });
  }

  const eventsByUser = await deps.gamification.listEventsForUsers(ctx, memberships.map((m) => m.userId));

  const scored: ScoredEntry[] = memberships.map((m) => {
    const events = eventsByUser[m.userId] ?? [];
    const score = computeScore(events, metric, window.start, window.end);
    const tieBreakValues = tieBreakers.map((eventType) =>
      events.filter((e) =>
        e.eventType === eventType && (!window.start || e.occurredAt >= window.start) &&
        (!window.end || e.occurredAt <= window.end)
      ).length
    );
    return { userId: m.userId, score, tieBreakValues };
  });

  const ranked = rankEntries(scored);
  await deps.leaderboard.saveSnapshot(
    ctx,
    key,
    periodKey,
    ranked.map((r) => ({ userId: r.userId, rank: r.rank, score: r.score })),
  );
  return json({ period_key: periodKey, entries: ranked.length });
}
