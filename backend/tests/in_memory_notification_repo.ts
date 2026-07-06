import type { AppContext } from "../functions/api/types.ts";
import type {
  DeliveryLogEntry,
  DeliveryLogRepo,
  DeliveryStatus,
  NotificationPref,
  NotificationPrefsRepo,
} from "../functions/api/notification_types.ts";

export class InMemoryNotificationPrefsRepo implements NotificationPrefsRepo {
  private byUser = new Map<string, Map<string, NotificationPref>>();

  list(_ctx: AppContext, userId: string): Promise<NotificationPref[]> {
    return Promise.resolve([...(this.byUser.get(userId)?.values() ?? [])]);
  }

  upsert(_ctx: AppContext, userId: string, pref: NotificationPref): Promise<void> {
    const prefs = this.byUser.get(userId) ?? new Map();
    prefs.set(pref.notificationTypeKey, pref);
    this.byUser.set(userId, prefs);
    return Promise.resolve();
  }
}

let deliveryCounter = 0;

export class InMemoryDeliveryLogRepo implements DeliveryLogRepo {
  entries: DeliveryLogEntry[] = [];

  countSentSince(_ctx: AppContext, userId: string, since: Date): Promise<number> {
    return Promise.resolve(
      this.entries.filter((e) => e.userId === userId && e.status === "sent" && e.sentAt >= since).length,
    );
  }

  record(
    _ctx: AppContext,
    campaignKey: string,
    userId: string,
    status: DeliveryStatus,
  ): Promise<DeliveryLogEntry> {
    deliveryCounter += 1;
    const entry: DeliveryLogEntry = {
      id: `delivery-${deliveryCounter.toString().padStart(4, "0")}`,
      campaignKey,
      userId,
      sentAt: new Date(),
      status,
      openedAt: null,
    };
    this.entries.push(entry);
    return Promise.resolve(entry);
  }

  markOpened(_ctx: AppContext, deliveryId: string): Promise<boolean> {
    const entry = this.entries.find((e) => e.id === deliveryId);
    if (!entry) return Promise.resolve(false);
    entry.openedAt = new Date();
    return Promise.resolve(true);
  }
}
