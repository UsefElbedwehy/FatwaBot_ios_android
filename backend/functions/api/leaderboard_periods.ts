// Period-key + scoring-window helpers for the leaderboard engine
// (docs/features/leaderboard.md). Week/month keys are simple partitioning
// identifiers (not strict ISO-8601 week numbers) — good enough since
// they're only used to key snapshot rows, not displayed to users.

export type LeaderboardPeriod = "weekly" | "monthly" | "seasonal" | "lifetime" | "challenge";

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
    case "lifetime":
      return { start: null, end: null };
    case "seasonal":
    case "challenge":
      return { start: season.startsAt, end: season.endsAt ?? now };
  }
}
