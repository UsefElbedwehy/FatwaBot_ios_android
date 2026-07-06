import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AppContext } from "./types.ts";
import type {
  DeliveryLogEntry,
  DeliveryLogRepo,
  DeliveryStatus,
  NotificationPref,
  NotificationPrefsRepo,
} from "./notification_types.ts";

export class SupabaseNotificationPrefsRepo implements NotificationPrefsRepo {
  constructor(private readonly db: SupabaseClient) {}

  async list(ctx: AppContext, userId: string): Promise<NotificationPref[]> {
    const { data, error } = await this.db
      .schema("notifications").from("user_prefs")
      .select("notification_type_key,enabled,offset_minutes")
      .eq("app_id", ctx.appId).eq("user_id", userId);
    if (error) throw error;
    return (data ?? []).map((r) => ({
      notificationTypeKey: r.notification_type_key,
      enabled: r.enabled,
      offsetMinutes: r.offset_minutes,
    }));
  }

  async upsert(ctx: AppContext, userId: string, pref: NotificationPref): Promise<void> {
    const { error } = await this.db
      .schema("notifications").from("user_prefs")
      .upsert(
        {
          app_id: ctx.appId,
          user_id: userId,
          notification_type_key: pref.notificationTypeKey,
          enabled: pref.enabled,
          offset_minutes: pref.offsetMinutes,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "app_id,user_id,notification_type_key" },
      );
    if (error) throw error;
  }
}

export class SupabaseDeliveryLogRepo implements DeliveryLogRepo {
  constructor(private readonly db: SupabaseClient) {}

  async countSentSince(ctx: AppContext, userId: string, since: Date): Promise<number> {
    const { count, error } = await this.db
      .schema("notifications").from("delivery_log")
      .select("id", { count: "exact", head: true })
      .eq("app_id", ctx.appId).eq("user_id", userId).eq("status", "sent")
      .gte("sent_at", since.toISOString());
    if (error) throw error;
    return count ?? 0;
  }

  async record(
    ctx: AppContext,
    campaignKey: string,
    userId: string,
    status: DeliveryStatus,
  ): Promise<DeliveryLogEntry> {
    const { data, error } = await this.db
      .schema("notifications").from("delivery_log")
      .insert({ app_id: ctx.appId, campaign_key: campaignKey, user_id: userId, status })
      .select("*")
      .single();
    if (error) throw error;
    return {
      id: data.id,
      campaignKey: data.campaign_key,
      userId: data.user_id,
      sentAt: new Date(data.sent_at),
      status: data.status,
      openedAt: data.opened_at ? new Date(data.opened_at) : null,
    };
  }

  async markOpened(ctx: AppContext, deliveryId: string): Promise<boolean> {
    const { data, error } = await this.db
      .schema("notifications").from("delivery_log")
      .update({ opened_at: new Date().toISOString() })
      .eq("app_id", ctx.appId).eq("id", deliveryId)
      .select("id");
    if (error) throw error;
    return (data?.length ?? 0) > 0;
  }
}
