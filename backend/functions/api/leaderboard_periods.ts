// Period-key + scoring-window helpers for the leaderboard engine
// (docs/features/leaderboard.md). Week/month keys are simple partitioning
// identifiers (not strict ISO-8601 week numbers) — good enough since
// they're only used to key snapshot rows, not displayed to users.

export type LeaderboardPeriod = "weekly" | "monthly" | "halfyearly" | "seasonal" | "lifetime" | "challenge";

export interface Season {
  startsAt: Date | null;
  endsAt: Date | null;
}

function pad(n: number): string {
  return String(n).padStart(2, "0");
}

function startOfWeekUtc(date: Date): Date {
  const start = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
  const diffDays = Math.floor((date.getTime() - start.getTime()) / 86_400_000);
  const weekIndex = Math.floor(diffDays / 7);
  return new Date(start.getTime() + weekIndex * 7 * 86_400_000);
}

/** Calendar halves — Jan-Jun and Jul-Dec — computed purely from `date`, the
 * same way weekly/monthly are. No admin-set dates, so the leaderboard rolls
 * to the next half on its own; nothing needs to remember to update it every
 * six months the way `seasonal`'s season_starts_at/ends_at would. */
function halfYearIndexOf(date: Date): 1 | 2 {
  return date.getUTCMonth() < 6 ? 1 : 2;
}

function startOfHalfYearUtc(date: Date): Date {
  const startMonth = halfYearIndexOf(date) === 1 ? 0 : 6;
  return new Date(Date.UTC(date.getUTCFullYear(), startMonth, 1));
}

export function periodKeyFor(period: LeaderboardPeriod, now: Date, season: Season): string {
  switch (period) {
    case "weekly": {
      const weekStart = startOfWeekUtc(now);
      const weekIndex = Math.floor(
        (weekStart.getTime() - Date.UTC(now.getUTCFullYear(), 0, 1)) / (7 * 86_400_000),
      );
      return `${now.getUTCFullYear()}-W${pad(weekIndex + 1)}`;
    }
    case "monthly":
      return `${now.getUTCFullYear()}-${pad(now.getUTCMonth() + 1)}`;
    case "halfyearly":
      return `${now.getUTCFullYear()}-H${halfYearIndexOf(now)}`;
    case "lifetime":
      return "lifetime";
    case "seasonal":
    case "challenge":
      return season.startsAt ? `season-${season.startsAt.toISOString().slice(0, 10)}` : "season-unset";
  }
}

/** The [start, end] instants that count toward the current period's score. */
export function windowFor(
  period: LeaderboardPeriod,
  now: Date,
  season: Season,
): { start: Date | null; end: Date | null } {
  switch (period) {
    case "weekly":
      return { start: startOfWeekUtc(now), end: now };
    case "monthly":
      return { start: new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)), end: now };
    case "halfyearly":
      return { start: startOfHalfYearUtc(now), end: now };
    case "lifetime":
      return { start: null, end: null };
    case "seasonal":
    case "challenge":
      return { start: season.startsAt, end: season.endsAt ?? now };
  }
}

/**
 * The current period's full calendar bounds — unlike `windowFor`, `end` is the
 * *next* boundary, not `now`. `windowFor` answers "what counts toward the
 * score so far"; this answers "when does the board reset", which is what a
 * client needs to show a countdown. Scoring can't include events that haven't
 * happened yet, but a reset date is known in advance.
 */
export function periodBoundsFor(
  period: LeaderboardPeriod,
  now: Date,
  season: Season,
): { start: Date | null; end: Date | null } {
  switch (period) {
    case "weekly": {
      const start = startOfWeekUtc(now);
      return { start, end: new Date(start.getTime() + 7 * 86_400_000) };
    }
    case "monthly": {
      const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
      const end = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));
      return { start, end };
    }
    case "halfyearly": {
      const start = startOfHalfYearUtc(now);
      const endMonth = halfYearIndexOf(now) === 1 ? 6 : 12;
      return { start, end: new Date(Date.UTC(now.getUTCFullYear(), endMonth, 1)) };
    }
    case "lifetime":
      return { start: null, end: null };
    case "seasonal":
    case "challenge":
      return { start: season.startsAt, end: season.endsAt };
  }
}
