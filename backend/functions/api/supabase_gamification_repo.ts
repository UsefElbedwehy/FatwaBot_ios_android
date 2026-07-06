import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AppContext } from "./types.ts";
import type { ActivityEventInput, GamificationRepo, StoredActivityEvent } from "./gamification_types.ts";

export class SupabaseGamificationRepo implements GamificationRepo {
  constructor(private readonly db: SupabaseClient) {}

  async recordEvents(
    ctx: AppContext,
    userId: string,
    events: ActivityEventInput[],
  ): Promise<{ accepted: number; duplicates: number }> {
    if (events.length === 0) return { accepted: 0, duplicates: 0 };
    const { data, error } = await this.db
      .schema("gamification").from("activity_events")
      .upsert(
        events.map((e) => ({
          app_id: ctx.appId,
          user_id: userId,
          event_type: e.eventType,
          client_event_id: e.clientEventId,
          occurred_at: e.occurredAt,
          timezone: e.timezone,
          metadata: e.metadata ?? {},
        })),
        { onConflict: "app_id,user_id,client_event_id", ignoreDuplicates: true },
      )
      .select("id");
    if (error) throw error;
    const accepted = data?.length ?? 0;
    return { accepted, duplicates: events.length - accepted };
  }

  async listEvents(ctx: AppContext, userId: string): Promise<StoredActivityEvent[]> {
    const { data, error } = await this.db
      .schema("gamification").from("activity_events")
      .select("event_type,occurred_at,timezone")
      .eq("app_id", ctx.appId).eq("user_id", userId);
    if (error) throw error;
    return (data ?? []).map((r) => ({
      eventType: r.event_type,
      occurredAt: new Date(r.occurred_at),
      timezone: r.timezone,
    }));
  }
}
