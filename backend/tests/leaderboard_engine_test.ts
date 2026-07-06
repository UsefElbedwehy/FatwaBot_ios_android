import { assertEquals } from "jsr:@std/assert@1";
import { computeScore, rankEntries } from "../functions/api/leaderboard_engine.ts";
import { periodKeyFor, windowFor } from "../functions/api/leaderboard_periods.ts";

Deno.test("computeScore: weighted sum over terms, each capped independently", () => {
  const events = [
    { eventType: "azkar_completed", occurredAt: new Date("2026-07-01T00:00:00Z"), timezone: "UTC" },
    { eventType: "azkar_completed", occurredAt: new Date("2026-07-02T00:00:00Z"), timezone: "UTC" },
    { eventType: "azkar_completed", occurredAt: new Date("2026-07-03T00:00:00Z"), timezone: "UTC" },
    { eventType: "tasbeeh_session_completed", occurredAt: new Date("2026-07-01T00:00:00Z"), timezone: "UTC" },
  ];
  const metric = {
    terms: [
      { eventType: "azkar_completed", weight: 10, capPerPeriod: 2 }, // 3 occurrences capped to 2 -> 20
      { eventType: "tasbeeh_session_completed", weight: 5, capPerPeriod: 10 }, // 1 -> 5
    ],
  };
  const score = computeScore(events, metric, null, null);
  assertEquals(score, 25);
});

Deno.test("computeScore: respects the scoring window", () => {
  const events = [
    { eventType: "azkar_completed", occurredAt: new Date("2026-07-01T00:00:00Z"), timezone: "UTC" },
    { eventType: "azkar_completed", occurredAt: new Date("2026-07-10T00:00:00Z"), timezone: "UTC" },
  ];
  const metric = { terms: [{ eventType: "azkar_completed", weight: 1, capPerPeriod: 100 }] };
  const score = computeScore(
    events,
    metric,
    new Date("2026-07-05T00:00:00Z"),
    new Date("2026-07-15T00:00:00Z"),
  );
  assertEquals(score, 1);
});

Deno.test("rankEntries: orders by score desc, then tie-breakers in priority order", () => {
  const entries = [
    { userId: "a", score: 10, tieBreakValues: [1] },
    { userId: "b", score: 20, tieBreakValues: [0] },
    { userId: "c", score: 10, tieBreakValues: [5] },
  ];
  const ranked = rankEntries(entries);
  assertEquals(ranked.map((r) => r.userId), ["b", "c", "a"]);
  assertEquals(ranked.map((r) => r.rank), [1, 2, 3]);
});

Deno.test("rankEntries: fully tied entries still get sequential ranks", () => {
  const entries = [
    { userId: "a", score: 5, tieBreakValues: [] },
    { userId: "b", score: 5, tieBreakValues: [] },
  ];
  const ranked = rankEntries(entries);
  assertEquals(ranked.map((r) => r.rank), [1, 2]);
});

Deno.test("periodKeyFor: lifetime is a fixed key regardless of date", () => {
  const key = periodKeyFor("lifetime", new Date("2026-07-06T00:00:00Z"), { startsAt: null, endsAt: null });
  assertEquals(key, "lifetime");
});

Deno.test("periodKeyFor: monthly key is stable within the same month", () => {
  const a = periodKeyFor("monthly", new Date("2026-07-01T00:00:00Z"), { startsAt: null, endsAt: null });
  const b = periodKeyFor("monthly", new Date("2026-07-31T23:00:00Z"), { startsAt: null, endsAt: null });
  assertEquals(a, b);
  assertEquals(a, "2026-07");
});

Deno.test("periodKeyFor: weekly key changes across a week boundary", () => {
  const week1 = periodKeyFor("weekly", new Date("2026-01-01T00:00:00Z"), { startsAt: null, endsAt: null });
  const week2 = periodKeyFor("weekly", new Date("2026-01-10T00:00:00Z"), { startsAt: null, endsAt: null });
  assertEquals(week1 === week2, false);
});

Deno.test("windowFor: monthly window starts at the 1st of the current month", () => {
  const window = windowFor("monthly", new Date("2026-07-15T12:00:00Z"), { startsAt: null, endsAt: null });
  assertEquals(window.start?.toISOString(), "2026-07-01T00:00:00.000Z");
});

Deno.test("windowFor: seasonal window uses the def's season bounds", () => {
  const season = { startsAt: new Date("2026-06-01T00:00:00Z"), endsAt: new Date("2026-06-30T00:00:00Z") };
  const window = windowFor("seasonal", new Date("2026-07-01T00:00:00Z"), season);
  assertEquals(window.start, season.startsAt);
  assertEquals(window.end, season.endsAt);
});

Deno.test("windowFor: lifetime has no bounds", () => {
  const window = windowFor("lifetime", new Date(), { startsAt: null, endsAt: null });
  assertEquals(window.start, null);
  assertEquals(window.end, null);
});
