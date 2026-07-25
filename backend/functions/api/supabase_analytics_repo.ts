import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AppContext } from "./types.ts";
import type { AnalyticsEventInput, AnalyticsRepo } from "./analytics_types.ts";

export class SupabaseAnalyticsRepo implements AnalyticsRepo {
  constructor(private readonly db: SupabaseClient) {}

  async recordEvents(
    ctx: AppContext,
    userId: string,
    events: AnalyticsEventInput[],
  ): Promise<{ accepted: number; duplicates: number }> {
    if (events.length === 0) return { accepted: 0, duplicates: 0 };
    // ignoreDuplicates on the (app_id, user_id, client_event_id) unique index:
    // a retried flush returns only the genuinely-new rows, so the count of
    // returned ids is the accepted count and the remainder are duplicates.
    const { data, error } = await this.db
      .schema("analytics").from("events")
      .upsert(
        events.map((e) => ({
          app_id: ctx.appId,
          user_id: userId,
          name: e.name,
          params: e.params ?? {},
          platform: e.platform ?? null,
          app_version: e.appVersion ?? null,
          client_event_id: e.clientEventId,
          occurred_at: e.occurredAt,
        })),
        { onConflict: "app_id,user_id,client_event_id", ignoreDuplicates: true },
      )
      .select("id");
    if (error) throw error;
    const accepted = data?.length ?? 0;
    return { accepted, duplicates: events.length - accepted };
  }
}
