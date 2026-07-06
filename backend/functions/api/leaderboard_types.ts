import type { AppContext } from "./types.ts";

export interface LeaderboardMembership {
  userId: string;
  handle: string;
  publishName: boolean;
  city: string | null;
  joinedAt: Date;
}

export interface SnapshotEntry {
  userId: string;
  rank: number;
  score: number;
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
  ): Promise<LeaderboardMembership>;
  leave(ctx: AppContext, leaderboardKey: string, userId: string): Promise<void>;
  updateMembership(
    ctx: AppContext,
    leaderboardKey: string,
    userId: string,
    changes: { publishName?: boolean; city?: string | null },
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
}
