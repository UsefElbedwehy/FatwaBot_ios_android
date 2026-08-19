import type { AppContext } from "./types.ts";

/** A single validated, privacy-screened analytics event ready for storage.
 * `params` values are already coerced to strings by the handler — the store
 * never sees raw client shapes. */
export interface AnalyticsEventInput {
  clientEventId: string;
  name: string;
  occurredAt: string; // ISO instant, as submitted by the client
  platform?: "ios" | "android";
  appVersion?: string;
  params?: Record<string, string>;
}

/** Write side for the product-analytics event log (migration 0023).
 * Deliberately NOT part of GamificationRepo: gamification.activity_events is
 * read in full per user to fold streaks on every profile request, so
 * high-volume screen-view traffic gets its own table and repo. Read/rollup
 * queries are dashboard/ops territory and aren't modelled here yet. */
export interface AnalyticsRepo {
  recordEvents(
    ctx: AppContext,
    userId: string,
    events: AnalyticsEventInput[],
  ): Promise<{ accepted: number; duplicates: number }>;
}
