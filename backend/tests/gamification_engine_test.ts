import { assertEquals } from "jsr:@std/assert@1";
import {
  badgeEarnedAt,
  computeStreak,
  localDateBucket,
  progressForCriteria,
  qualifyingDates,
  type StreakDef,
} from "../functions/api/gamification_engine.ts";

const RIYADH_DEF: StreakDef = {
  eventTypes: ["azkar_completed"],
  requiredDailyCount: 1,
  dayBoundaryType: "fixed_local_time",
  dayBoundaryLocalTime: "04:00",
  graceAllowance: 1,
  gracePeriodDays: 30,
};

function iso(dateTimeUtc: string): Date {
  return new Date(dateTimeUtc);
}

Deno.test("localDateBucket: an event before the boundary time counts toward the previous day", () => {
  // 2026-07-06 02:00 Asia/Riyadh (+03:00) = 2026-07-05 23:00 UTC; boundary is 04:00 local.
  const bucket = localDateBucket(iso("2026-07-05T23:00:00Z"), "Asia/Riyadh", RIYADH_DEF);
  assertEquals(bucket, "2026-07-05");
});

Deno.test("localDateBucket: an event after the boundary time counts toward that calendar day", () => {
  // 2026-07-06 05:00 Asia/Riyadh = 2026-07-06T02:00:00Z
  const bucket = localDateBucket(iso("2026-07-06T02:00:00Z"), "Asia/Riyadh", RIYADH_DEF);
  assertEquals(bucket, "2026-07-06");
});

Deno.test("localDateBucket: midnight boundary uses the plain calendar date", () => {
  const midnightDef = { ...RIYADH_DEF, dayBoundaryType: "midnight" as const };
  const bucket = localDateBucket(iso("2026-07-06T02:00:00Z"), "Asia/Riyadh", midnightDef);
  assertEquals(bucket, "2026-07-06");
});

Deno.test("qualifyingDates: a day only qualifies once requiredDailyCount is met", () => {
  const def = { ...RIYADH_DEF, requiredDailyCount: 2 };
  const events = [
    { eventType: "azkar_completed", occurredAt: iso("2026-07-06T06:00:00Z"), timezone: "Asia/Riyadh" },
  ];
  assertEquals(qualifyingDates(events, def).size, 0);
  events.push({
    eventType: "azkar_completed",
    occurredAt: iso("2026-07-06T07:00:00Z"),
    timezone: "Asia/Riyadh",
  });
  assertEquals(qualifyingDates(events, def).size, 1);
});

Deno.test("computeStreak: consecutive qualifying days build a run; today counts", () => {
  const events = [
    { eventType: "azkar_completed", occurredAt: iso("2026-07-04T06:00:00Z"), timezone: "Asia/Riyadh" },
    { eventType: "azkar_completed", occurredAt: iso("2026-07-05T06:00:00Z"), timezone: "Asia/Riyadh" },
    { eventType: "azkar_completed", occurredAt: iso("2026-07-06T06:00:00Z"), timezone: "Asia/Riyadh" },
  ];
  const result = computeStreak(events, RIYADH_DEF, "2026-07-06");
  assertEquals(result.currentLength, 3);
  assertEquals(result.longestLength, 3);
});

Deno.test("computeStreak: a missed day with no grace resets the current streak but preserves the longest", () => {
  const noGraceDef = { ...RIYADH_DEF, graceAllowance: 0 };
  const events = [
    { eventType: "azkar_completed", occurredAt: iso("2026-07-01T06:00:00Z"), timezone: "Asia/Riyadh" },
    { eventType: "azkar_completed", occurredAt: iso("2026-07-02T06:00:00Z"), timezone: "Asia/Riyadh" },
    // 07-03 missing
    { eventType: "azkar_completed", occurredAt: iso("2026-07-04T06:00:00Z"), timezone: "Asia/Riyadh" },
  ];
  const result = computeStreak(events, noGraceDef, "2026-07-04");
  assertEquals(result.currentLength, 1);
  assertEquals(result.longestLength, 2);
});

Deno.test("computeStreak: a grace day preserves the streak without extending its length", () => {
  const events = [
    { eventType: "azkar_completed", occurredAt: iso("2026-07-01T06:00:00Z"), timezone: "Asia/Riyadh" },
    { eventType: "azkar_completed", occurredAt: iso("2026-07-02T06:00:00Z"), timezone: "Asia/Riyadh" },
    // 07-03 missing, forgiven by grace (RIYADH_DEF has graceAllowance: 1)
    { eventType: "azkar_completed", occurredAt: iso("2026-07-04T06:00:00Z"), timezone: "Asia/Riyadh" },
  ];
  const result = computeStreak(events, RIYADH_DEF, "2026-07-04");
  // Streak wasn't reset by the grace day, and the qualifying day after it extends it to 3.
  assertEquals(result.currentLength, 3);
  assertEquals(result.graceRemaining, 0);
});

Deno.test("computeStreak: a second miss more than gracePeriodDays after the first is forgiven again (token replenished)", () => {
  const def = { ...RIYADH_DEF, graceAllowance: 1, gracePeriodDays: 5 };
  const events = [
    { eventType: "azkar_completed", occurredAt: iso("2026-07-01T06:00:00Z"), timezone: "Asia/Riyadh" },
    // 07-02 missing — uses the one grace token
    { eventType: "azkar_completed", occurredAt: iso("2026-07-03T06:00:00Z"), timezone: "Asia/Riyadh" },
    { eventType: "azkar_completed", occurredAt: iso("2026-07-04T06:00:00Z"), timezone: "Asia/Riyadh" },
    { eventType: "azkar_completed", occurredAt: iso("2026-07-05T06:00:00Z"), timezone: "Asia/Riyadh" },
    { eventType: "azkar_completed", occurredAt: iso("2026-07-06T06:00:00Z"), timezone: "Asia/Riyadh" },
    { eventType: "azkar_completed", occurredAt: iso("2026-07-07T06:00:00Z"), timezone: "Asia/Riyadh" },
    // 07-08 missing — 6 days after the first grace use, outside the 5-day window, so a fresh token is available
  ];
  const result = computeStreak(events, def, "2026-07-08");
  // Both misses were forgiven: the streak was never reset, so it's still running as of 07-08.
  assertEquals(result.currentLength, 6);
  assertEquals(result.longestLength, 6);
  // The most recent grace use (07-08) is still within its own window, so no token is free right now.
  assertEquals(result.graceRemaining, 0);
});

Deno.test("computeStreak: no qualifying events at all yields a zero streak with full grace", () => {
  const result = computeStreak([], RIYADH_DEF, "2026-07-06");
  assertEquals(result, { currentLength: 0, longestLength: 0, graceRemaining: 1 });
});

Deno.test("progressForCriteria: lifetime window counts everything, capped at target", () => {
  const events = Array.from(
    { length: 5 },
    (_, i) => ({
      eventType: "tasbeeh_session_completed",
      occurredAt: iso(`2026-07-0${i + 1}T06:00:00Z`),
      timezone: "UTC",
    }),
  );
  const result = progressForCriteria(events, {
    eventType: "tasbeeh_session_completed",
    targetCount: 3,
    window: "lifetime",
  }, new Date("2026-07-10T00:00:00Z"));
  assertEquals(result, { count: 3, target: 3 });
});

Deno.test("progressForCriteria: daily window excludes events older than 24h", () => {
  const now = new Date("2026-07-10T12:00:00Z");
  const events = [
    { eventType: "wird_ticked", occurredAt: new Date("2026-07-10T10:00:00Z"), timezone: "UTC" },
    { eventType: "wird_ticked", occurredAt: new Date("2026-07-08T10:00:00Z"), timezone: "UTC" },
  ];
  const result = progressForCriteria(
    events,
    { eventType: "wird_ticked", targetCount: 5, window: "daily" },
    now,
  );
  assertEquals(result.count, 1);
});

Deno.test("badgeEarnedAt: returns the instant the target count was first reached, or null", () => {
  const events = [
    { eventType: "hadith_entry_read", occurredAt: iso("2026-07-01T00:00:00Z"), timezone: "UTC" },
    { eventType: "hadith_entry_read", occurredAt: iso("2026-07-02T00:00:00Z"), timezone: "UTC" },
  ];
  const notYet = badgeEarnedAt(events, {
    eventType: "hadith_entry_read",
    targetCount: 3,
    window: "lifetime",
  });
  assertEquals(notYet, null);

  const earned = badgeEarnedAt(events, {
    eventType: "hadith_entry_read",
    targetCount: 2,
    window: "lifetime",
  });
  assertEquals(earned?.toISOString(), "2026-07-02T00:00:00.000Z");
});
