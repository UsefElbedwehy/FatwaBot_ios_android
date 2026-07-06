import type { AppContext } from "./types.ts";

export interface ActivityEventInput {
  clientEventId: string;
  eventType: string;
  occurredAt: string; // ISO instant, as submitted by the client
  timezone: string;
  metadata?: Record<string, unknown>;
}

export interface StoredActivityEvent {
  eventType: string;
  occurredAt: Date;
  timezone: string;
}

/** Write/read side for the raw activity-event log. Definitions (streak_defs/
 * missions/badges) are NOT covered here — they go through the generic
 * AdminContentRepo, same as content-domain rows (docs/features/gamification.md). */
export interface GamificationRepo {
  recordEvents(
    ctx: AppContext,
    userId: string,
    events: ActivityEventInput[],
  ): Promise<{ accepted: number; duplicates: number }>;
  listEvents(ctx: AppContext, userId: string): Promise<StoredActivityEvent[]>;
}
