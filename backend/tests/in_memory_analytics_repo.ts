import type { AppContext } from "../functions/api/types.ts";
import type { AnalyticsEventInput, AnalyticsRepo } from "../functions/api/analytics_types.ts";

export class InMemoryAnalyticsRepo implements AnalyticsRepo {
  // keyed by `${userId}:${clientEventId}` for idempotency, mirroring the
  // (app_id, user_id, client_event_id) unique index in migration 0023.
  private seen = new Set<string>();
  private byUser = new Map<string, AnalyticsEventInput[]>();

  recordEvents(
    _ctx: AppContext,
    userId: string,
    events: AnalyticsEventInput[],
  ): Promise<{ accepted: number; duplicates: number }> {
    let accepted = 0;
    let duplicates = 0;
    for (const e of events) {
      const key = `${userId}:${e.clientEventId}`;
      if (this.seen.has(key)) {
        duplicates += 1;
        continue;
      }
      this.seen.add(key);
      const list = this.byUser.get(userId) ?? [];
      list.push(e);
      this.byUser.set(userId, list);
      accepted += 1;
    }
    return Promise.resolve({ accepted, duplicates });
  }

  /** Test-only: what actually reached storage (not part of AnalyticsRepo). */
  stored(userId: string): AnalyticsEventInput[] {
    return this.byUser.get(userId) ?? [];
  }
}
