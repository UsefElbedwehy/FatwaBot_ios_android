import type { AppContext } from "./types.ts";

export interface NotificationPref {
  notificationTypeKey: string;
  enabled: boolean;
  offsetMinutes: number | null;
}

/** Per-user notification preferences (docs/features/notification-campaigns.md
 * layer 1). Catalog itself (config.notification_types) is admin content and
 * goes through the generic AdminContentRepo. */
export interface NotificationPrefsRepo {
  list(ctx: AppContext, userId: string): Promise<NotificationPref[]>;
  upsert(ctx: AppContext, userId: string, pref: NotificationPref): Promise<void>;
}

export type DeliveryStatus = "sent" | "failed" | "capped";

export interface DeliveryLogEntry {
  id: string;
  campaignKey: string;
  userId: string;
  sentAt: Date;
  status: DeliveryStatus;
  openedAt: Date | null;
}

/** Append-only campaign delivery record (layer 3). Only remote *campaign*
 * sends are ever logged here — worship/gamification notifications are
 * locally computed on-device (ADR-0003) and never touch this table, so no
 * category discriminator is needed on the count. Real FCM dispatch is out
 * of scope until Firebase credentials exist (Q8) — `record` is called by
 * the admin-triggered dispatch handler with a `sent` status as a
 * placeholder, same self-issued-now / swappable-later pattern as ADR-0004. */
export interface DeliveryLogRepo {
  /** Count of 'sent' deliveries to this user at/after `since` (the cap
   * window's start), across all campaigns. */
  countSentSince(ctx: AppContext, userId: string, since: Date): Promise<number>;
  record(
    ctx: AppContext,
    campaignKey: string,
    userId: string,
    status: DeliveryStatus,
  ): Promise<DeliveryLogEntry>;
  markOpened(ctx: AppContext, deliveryId: string): Promise<boolean>;
}
