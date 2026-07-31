import type { AppContext } from "./types.ts";

export interface LeaderboardMembership {
  userId: string;
  handle: string;
  publishName: boolean;
  city: string | null;
  /** ISO 3166-1 alpha-2, uppercased. Opt-in, same rule as `city`. */
  country: string | null;
  joinedAt: Date;
}

export interface SnapshotEntry {
  userId: string;
  rank: number;
  score: number;
  /**
   * Region this rank is relative to: empty for global boards, the country code
   * for country scope, the city name for city scope. Empty rather than null
   * because it is part of the lookup key on every read.
   */
  bucket: string;
}

/** Membership + materialized-snapshot storage. Leaderboard *definitions*
 * (leaderboard_defs) are admin content and go through the generic
 * AdminContentRepo, same as streak_defs/missions/badges. */
export interface LeaderboardRepo {
  join(
    ctx: AppContext,
    leaderboardKey: string,
    userId: string,
    publishName: boolean,
    city: string | null,
    country: string | null,
  ): Promise<LeaderboardMembership>;
  leave(ctx: AppContext, leaderboardKey: string, userId: string): Promise<void>;
  updateMembership(
    ctx: AppContext,
    leaderboardKey: string,
    userId: string,
    changes: { publishName?: boolean; city?: string | null; country?: string | null },
  ): Promise<LeaderboardMembership | null>;
  getMembership(
    ctx: AppContext,
    leaderboardKey: string,
    userId: string,
  ): Promise<LeaderboardMembership | null>;
  listMemberships(ctx: AppContext, leaderboardKey: string): Promise<LeaderboardMembership[]>;

  saveSnapshot(
    ctx: AppContext,
    leaderboardKey: string,
    periodKey: string,
    entries: SnapshotEntry[],
  ): Promise<void>;
  getSnapshot(ctx: AppContext, leaderboardKey: string, periodKey: string): Promise<SnapshotEntry[]>;
  /**
   * When this board's snapshot for `periodKey` was last materialized, or null
   * if it never was. Drives the staleness check that keeps standings fresh
   * without an external scheduler.
   */
  snapshotComputedAt(
    ctx: AppContext,
    leaderboardKey: string,
    periodKey: string,
  ): Promise<Date | null>;
}
