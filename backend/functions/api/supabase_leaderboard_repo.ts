import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AppContext } from "./types.ts";
import type { LeaderboardMembership, LeaderboardRepo, SnapshotEntry } from "./leaderboard_types.ts";

/** Auto-generated pseudonym (ADR-0007: leaderboards are pseudonymous by
 * default). Generated fresh per join — a user's handle can differ across
 * boards; a shared cross-board handle is a natural extension if that
 * distinction turns out to matter. */
export function generateHandle(): string {
  const suffix = crypto.getRandomValues(new Uint32Array(1))[0].toString(36).slice(0, 6);
  return `Muslim_${suffix}`;
}

function toMembership(row: Record<string, unknown>): LeaderboardMembership {
  return {
    userId: row.user_id as string,
    handle: row.handle as string,
    publishName: Boolean(row.publish_name),
    city: (row.city as string | null) ?? null,
    country: (row.country as string | null) ?? null,
    joinedAt: new Date(row.joined_at as string),
  };
}

export class SupabaseLeaderboardRepo implements LeaderboardRepo {
  constructor(private readonly db: SupabaseClient) {}

  async join(
    ctx: AppContext,
    leaderboardKey: string,
    userId: string,
    publishName: boolean,
    city: string | null,
    country: string | null,
  ): Promise<LeaderboardMembership> {
    const { data, error } = await this.db
      .schema("gamification").from("leaderboard_memberships")
      .upsert(
        {
          app_id: ctx.appId,
          leaderboard_key: leaderboardKey,
          user_id: userId,
          handle: generateHandle(),
          publish_name: publishName,
          city,
          country,
        },
        { onConflict: "app_id,leaderboard_key,user_id" },
      )
      .select("*")
      .single();
    if (error) throw error;
    return toMembership(data);
  }

  async leave(ctx: AppContext, leaderboardKey: string, userId: string): Promise<void> {
    const { error } = await this.db
      .schema("gamification").from("leaderboard_memberships")
      .delete()
      .eq("app_id", ctx.appId).eq("leaderboard_key", leaderboardKey).eq("user_id", userId);
    if (error) throw error;
  }

  async updateMembership(
    ctx: AppContext,
    leaderboardKey: string,
    userId: string,
    changes: { publishName?: boolean; city?: string | null; country?: string | null },
  ): Promise<LeaderboardMembership | null> {
    const patch: Record<string, unknown> = {};
    if (changes.publishName !== undefined) patch.publish_name = changes.publishName;
    if (changes.city !== undefined) patch.city = changes.city;
    if (changes.country !== undefined) patch.country = changes.country;

    const { data, error } = await this.db
      .schema("gamification").from("leaderboard_memberships")
      .update(patch)
      .eq("app_id", ctx.appId).eq("leaderboard_key", leaderboardKey).eq("user_id", userId)
      .select("*")
      .maybeSingle();
    if (error) throw error;
    return data ? toMembership(data) : null;
  }

  async getMembership(
    ctx: AppContext,
    leaderboardKey: string,
    userId: string,
  ): Promise<LeaderboardMembership | null> {
    const { data, error } = await this.db
      .schema("gamification").from("leaderboard_memberships")
      .select("*")
      .eq("app_id", ctx.appId).eq("leaderboard_key", leaderboardKey).eq("user_id", userId)
      .maybeSingle();
    if (error) throw error;
    return data ? toMembership(data) : null;
  }

  async listMemberships(ctx: AppContext, leaderboardKey: string): Promise<LeaderboardMembership[]> {
    const { data, error } = await this.db
      .schema("gamification").from("leaderboard_memberships")
      .select("*")
      .eq("app_id", ctx.appId).eq("leaderboard_key", leaderboardKey);
    if (error) throw error;
    return (data ?? []).map(toMembership);
  }

  async saveSnapshot(
    ctx: AppContext,
    leaderboardKey: string,
    periodKey: string,
    entries: SnapshotEntry[],
  ): Promise<void> {
    if (entries.length === 0) return;
    const { error } = await this.db
      .schema("gamification").from("leaderboard_snapshots")
      .upsert(
        entries.map((e) => ({
          app_id: ctx.appId,
          leaderboard_key: leaderboardKey,
          period_key: periodKey,
          user_id: e.userId,
          rank: e.rank,
          score: e.score,
          bucket: e.bucket,
          computed_at: new Date().toISOString(),
        })),
        { onConflict: "app_id,leaderboard_key,period_key,user_id" },
      );
    if (error) throw error;
  }

  async getSnapshot(ctx: AppContext, leaderboardKey: string, periodKey: string): Promise<SnapshotEntry[]> {
    const { data, error } = await this.db
      .schema("gamification").from("leaderboard_snapshots")
      .select("user_id,rank,score,bucket")
      .eq("app_id", ctx.appId).eq("leaderboard_key", leaderboardKey).eq("period_key", periodKey)
      .order("rank", { ascending: true });
    if (error) throw error;
    return (data ?? []).map((r) => ({
      userId: r.user_id,
      rank: r.rank,
      score: Number(r.score),
      bucket: (r.bucket as string | null) ?? "",
    }));
  }
}
