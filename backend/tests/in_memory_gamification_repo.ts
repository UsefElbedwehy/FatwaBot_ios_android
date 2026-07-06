import type { AppContext } from "../functions/api/types.ts";
import type {
  ActivityEventInput,
  GamificationRepo,
  StoredActivityEvent,
} from "../functions/api/gamification_types.ts";

export class InMemoryGamificationRepo implements GamificationRepo {
  // keyed by `${userId}:${clientEventId}` for idempotency
  private seen = new Map<string, StoredActivityEvent>();
  private byUser = new Map<string, StoredActivityEvent[]>();

  recordEvents(
    _ctx: AppContext,
    userId: string,
    events: ActivityEventInput[],
  ): Promise<{ accepted: number; duplicates: number }> {
    let accepted = 0;
    let duplicates = 0;
    for (const e of events) {
      const key = `${userId}:${e.clientEventId}`;
      if (this.seen.has(key)) {
        duplicates += 1;
        continue;
      }
      const stored: StoredActivityEvent = {
        eventType: e.eventType,
        occurredAt: new Date(e.occurredAt),
        timezone: e.timezone,
      };
      this.seen.set(key, stored);
      const list = this.byUser.get(userId) ?? [];
      list.push(stored);
      this.byUser.set(userId, list);
      accepted += 1;
    }
    return Promise.resolve({ accepted, duplicates });
  }

  listEvents(_ctx: AppContext, userId: string): Promise<StoredActivityEvent[]> {
    return Promise.resolve(this.byUser.get(userId) ?? []);
  }

  listEventsForUsers(_ctx: AppContext, userIds: string[]): Promise<Record<string, StoredActivityEvent[]>> {
    const byUser: Record<string, StoredActivityEvent[]> = {};
    for (const userId of userIds) {
      byUser[userId] = this.byUser.get(userId) ?? [];
    }
    return Promise.resolve(byUser);
  }
}
