import { assertEquals } from "jsr:@std/assert@1";
import { computeScore, rankEntries } from "../functions/api/leaderboard_engine.ts";
import { periodBoundsFor, periodKeyFor, windowFor } from "../functions/api/leaderboard_periods.ts";

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

// halfyearly — the 6-month leaderboard cycle the admin crowns a winner on.
// Calendar halves in UTC: H1 is Jan-Jun, H2 is Jul-Dec.

Deno.test("periodKeyFor: halfyearly key is stable within the same half", () => {
  const start = periodKeyFor("halfyearly", new Date("2026-01-01T00:00:00Z"), { startsAt: null, endsAt: null });
  const mid = periodKeyFor("halfyearly", new Date("2026-04-15T12:00:00Z"), { startsAt: null, endsAt: null });
  const end = periodKeyFor("halfyearly", new Date("2026-06-30T23:59:59Z"), { startsAt: null, endsAt: null });
  assertEquals(start, "2026-H1");
  assertEquals(mid, "2026-H1");
  assertEquals(end, "2026-H1");
});

Deno.test("periodKeyFor: halfyearly key changes exactly at the Jun/Jul boundary", () => {
  const juneLast = periodKeyFor("halfyearly", new Date("2026-06-30T23:59:59.999Z"), {
    startsAt: null,
    endsAt: null,
  });
  const julyFirst = periodKeyFor("halfyearly", new Date("2026-07-01T00:00:00.000Z"), {
    startsAt: null,
    endsAt: null,
  });
  assertEquals(juneLast, "2026-H1");
  assertEquals(julyFirst, "2026-H2");
});

Deno.test("periodKeyFor: halfyearly key changes at the year boundary too", () => {
  const decLast = periodKeyFor("halfyearly", new Date("2026-12-31T23:59:59Z"), { startsAt: null, endsAt: null });
  const janFirst = periodKeyFor("halfyearly", new Date("2027-01-01T00:00:00Z"), { startsAt: null, endsAt: null });
  assertEquals(decLast, "2026-H2");
  assertEquals(janFirst, "2027-H1");
});

Deno.test("windowFor: halfyearly window starts Jan 1 in H1, Jul 1 in H2, ends now", () => {
  const h1 = windowFor("halfyearly", new Date("2026-03-20T09:00:00Z"), { startsAt: null, endsAt: null });
  assertEquals(h1.start?.toISOString(), "2026-01-01T00:00:00.000Z");
  assertEquals(h1.end?.toISOString(), "2026-03-20T09:00:00.000Z");

  const h2 = windowFor("halfyearly", new Date("2026-09-05T00:00:00Z"), { startsAt: null, endsAt: null });
  assertEquals(h2.start?.toISOString(), "2026-07-01T00:00:00.000Z");
});

// periodBoundsFor — the client-facing "when does this reset" bound, distinct
// from windowFor: `end` is the *next* boundary, not `now`.

Deno.test("periodBoundsFor: halfyearly end is the start of the next half, not now", () => {
  const bounds = periodBoundsFor("halfyearly", new Date("2026-03-20T09:00:00Z"), { startsAt: null, endsAt: null });
  assertEquals(bounds.start?.toISOString(), "2026-01-01T00:00:00.000Z");
  assertEquals(bounds.end?.toISOString(), "2026-07-01T00:00:00.000Z");
});

Deno.test("periodBoundsFor: halfyearly in H2 ends at the start of next year's H1", () => {
  const bounds = periodBoundsFor("halfyearly", new Date("2026-09-05T00:00:00Z"), { startsAt: null, endsAt: null });
  assertEquals(bounds.start?.toISOString(), "2026-07-01T00:00:00.000Z");
  assertEquals(bounds.end?.toISOString(), "2027-01-01T00:00:00.000Z");
});

Deno.test("periodBoundsFor: weekly end is 7 days after the week start, not now", () => {
  const now = new Date("2026-01-10T15:00:00Z"); // mid-week
  const bounds = periodBoundsFor("weekly", now, { startsAt: null, endsAt: null });
  assertEquals(bounds.end?.getTime(), (bounds.start?.getTime() ?? 0) + 7 * 86_400_000);
  // Distinct from windowFor, whose end is always `now`.
  assertEquals(windowFor("weekly", now, { startsAt: null, endsAt: null }).end, now);
});

Deno.test("periodBoundsFor: monthly end is the 1st of next month, not now", () => {
  const bounds = periodBoundsFor("monthly", new Date("2026-02-15T00:00:00Z"), { startsAt: null, endsAt: null });
  assertEquals(bounds.start?.toISOString(), "2026-02-01T00:00:00.000Z");
  assertEquals(bounds.end?.toISOString(), "2026-03-01T00:00:00.000Z");
});

Deno.test("periodBoundsFor: lifetime has no bounds", () => {
  const bounds = periodBoundsFor("lifetime", new Date(), { startsAt: null, endsAt: null });
  assertEquals(bounds.start, null);
  assertEquals(bounds.end, null);
});

Deno.test("periodBoundsFor: seasonal reflects the def's dates as-is, including an unset end", () => {
  const season = { startsAt: new Date("2026-06-01T00:00:00Z"), endsAt: null };
  const bounds = periodBoundsFor("seasonal", new Date("2026-07-01T00:00:00Z"), season);
  assertEquals(bounds.start, season.startsAt);
  assertEquals(bounds.end, null); // no invented end — an admin hasn't set one
});
