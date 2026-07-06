// Pure notification-cap logic (docs/features/notification-campaigns.md, Q2d).
// Only campaign-category sends are ever subject to this cap — worship/
// gamification notifications are locally computed and never call this.

/** Whether one more campaign send to this user today is allowed. */
export function capCheckAllowed(sentSoFarToday: number, effectiveDailyCap: number): boolean {
  return sentSoFarToday < effectiveDailyCap;
}

export const DEFAULT_DAILY_CAP = 2;

export function effectiveDailyCap(campaignOverride: number | null | undefined): number {
  return campaignOverride ?? DEFAULT_DAILY_CAP;
}
