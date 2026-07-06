import type { AppContext } from "../functions/api/types.ts";
import type {
  LeaderboardMembership,
  LeaderboardRepo,
  SnapshotEntry,
} from "../functions/api/leaderboard_types.ts";

let counter = 0;
function nextHandle(): string {
  counter += 1;
  return `Muslim_test${counter.toString().padStart(3, "0")}`;
}

export class InMemoryLeaderboardRepo implements LeaderboardRepo {
  private memberships = new Map<string, LeaderboardMembership>(); // key: `${key}:${userId}`
  private snapshots = new Map<string, SnapshotEntry[]>(); // key: `${key}:${periodKey}`

  join(
    _ctx: AppContext,
    leaderboardKey: string,
    userId: string,
    publishName: boolean,
    city: string | null,
  ): Promise<LeaderboardMembership> {
    const membership: LeaderboardMembership = {
      userId,
      handle: nextHandle(),
      publishName,
      city,
      joinedAt: new Date(),
    };
    this.memberships.set(`${leaderboardKey}:${userId}`, membership);
    return Promise.resolve(membership);
  }

  leave(_ctx: AppContext, leaderboardKey: string, userId: string): Promise<void> {
    this.memberships.delete(`${leaderboardKey}:${userId}`);
    return Promise.resolve();
  }

  updateMembership(
    _ctx: AppContext,
    leaderboardKey: string,
    userId: string,
    changes: { publishName?: boolean; city?: string | null },
  ): Promise<LeaderboardMembership | null> {
    const key = `${leaderboardKey}:${userId}`;
    const existing = this.memberships.get(key);
    if (!existing) return Promise.resolve(null);
    const updated = {
      ...existing,
      publishName: changes.publishName ?? existing.publishName,
      city: changes.city !== undefined ? changes.city : existing.city,
    };
    this.memberships.set(key, updated);
    return Promise.resolve(updated);
  }

  getMembership(
    _ctx: AppContext,
    leaderboardKey: string,
    userId: string,
  ): Promise<LeaderboardMembership | null> {
    return Promise.resolve(this.memberships.get(`${leaderboardKey}:${userId}`) ?? null);
  }

  listMemberships(_ctx: AppContext, leaderboardKey: string): Promise<LeaderboardMembership[]> {
    return Promise.resolve(
      [...this.memberships.entries()]
        .filter(([k]) => k.startsWith(`${leaderboardKey}:`))
        .map(([, v]) => v),
    );
  }

  saveSnapshot(
    _ctx: AppContext,
    leaderboardKey: string,
    periodKey: string,
    entries: SnapshotEntry[],
  ): Promise<void> {
    this.snapshots.set(`${leaderboardKey}:${periodKey}`, entries);
    return Promise.resolve();
  }

  getSnapshot(_ctx: AppContext, leaderboardKey: string, periodKey: string): Promise<SnapshotEntry[]> {
    return Promise.resolve(this.snapshots.get(`${leaderboardKey}:${periodKey}`) ?? []);
  }
}
