// Pure gamification folding logic (docs/features/gamification.md). No I/O —
// takes a raw event log + admin-authored definitions, returns descriptors.
// Everything here is a pure function of its inputs so profile reads are
// always correct (no separately-drifting cache) and easy to unit-test.

export interface ActivityEventLite {
  eventType: string;
  occurredAt: Date;
  timezone: string;
}

export type DayBoundaryType = "fixed_local_time" | "midnight";

export interface StreakDef {
  eventTypes: string[];
  requiredDailyCount: number;
  dayBoundaryType: DayBoundaryType;
  /** "HH:MM", used only when dayBoundaryType is "fixed_local_time". */
  dayBoundaryLocalTime: string;
  graceAllowance: number;
  gracePeriodDays: number;
}

export interface StreakResult {
  currentLength: number;
  longestLength: number;
  graceRemaining: number;
}

export interface CriteriaDef {
  eventType: string;
  targetCount: number;
  window: "daily" | "weekly" | "lifetime";
}

export interface ProgressResult {
  count: number;
  target: number;
}

function toLocalParts(instant: Date, timeZone: string) {
  const fmt = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  const parts = Object.fromEntries(fmt.formatToParts(instant).map((p) => [p.type, p.value]));
  const hour = parts.hour === "24" ? 0 : Number(parts.hour);
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour,
    minute: Number(parts.minute),
  };
}

/** Which calendar day (as an ISO date string) an instant counts toward, per
 * the streak's day-boundary policy. See gamification.md's rationale for why
 * this is a configurable fixed local time rather than astronomical Fajr. */
export function localDateBucket(
  instant: Date,
  timezone: string,
  def: Pick<StreakDef, "dayBoundaryType" | "dayBoundaryLocalTime">,
): string {
  const local = toLocalParts(instant, timezone);
  const asUtcDate = new Date(Date.UTC(local.year, local.month - 1, local.day));
  if (def.dayBoundaryType === "midnight") {
    return asUtcDate.toISOString().slice(0, 10);
  }
  const [boundaryHour, boundaryMinute] = def.dayBoundaryLocalTime.split(":").map(Number);
  const beforeBoundary = local.hour < boundaryHour ||
    (local.hour === boundaryHour && local.minute < boundaryMinute);
  if (beforeBoundary) asUtcDate.setUTCDate(asUtcDate.getUTCDate() - 1);
  return asUtcDate.toISOString().slice(0, 10);
}

function addDaysISO(dateStr: string, delta: number): string {
  const d = new Date(`${dateStr}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + delta);
  return d.toISOString().slice(0, 10);
}

function daysBetweenISO(a: string, b: string): number {
  return Math.round(
    (new Date(`${b}T00:00:00Z`).getTime() - new Date(`${a}T00:00:00Z`).getTime()) / 86_400_000,
  );
}

/** The set of calendar days on which enough qualifying events occurred. */
export function qualifyingDates(events: ActivityEventLite[], def: StreakDef): Set<string> {
  const countsByDate = new Map<string, number>();
  for (const event of events) {
    if (!def.eventTypes.includes(event.eventType)) continue;
    const bucket = localDateBucket(event.occurredAt, event.timezone, def);
    countsByDate.set(bucket, (countsByDate.get(bucket) ?? 0) + 1);
  }
  const qualifying = new Set<string>();
  for (const [date, count] of countsByDate) {
    if (count >= def.requiredDailyCount) qualifying.add(date);
  }
  return qualifying;
}

/** Folds the streak day-by-day from the earliest qualifying day through
 * `todayLocalDate`. A grace day preserves the running streak (doesn't reset
 * it) but doesn't extend it either — only a real qualifying day increments
 * the count. Grace tokens are limited to `graceAllowance` per any trailing
 * `gracePeriodDays` window. */
export function computeStreak(
  events: ActivityEventLite[],
  def: StreakDef,
  todayLocalDate: string,
): StreakResult {
  const qualifying = qualifyingDates(events, def);
  if (qualifying.size === 0) {
    return { currentLength: 0, longestLength: 0, graceRemaining: def.graceAllowance };
  }

  const earliest = [...qualifying].sort()[0];
  let running = 0;
  let longest = 0;
  let graceUses: string[] = [];

  for (let cursor = earliest; cursor <= todayLocalDate; cursor = addDaysISO(cursor, 1)) {
    if (qualifying.has(cursor)) {
      running += 1;
    } else {
      graceUses = graceUses.filter((used) => daysBetweenISO(used, cursor) <= def.gracePeriodDays);
      if (graceUses.length < def.graceAllowance) {
        graceUses.push(cursor);
        // streak preserved, not extended
      } else {
        running = 0;
      }
    }
    longest = Math.max(longest, running);
  }

  const graceRemaining = def.graceAllowance -
    graceUses.filter((used) => daysBetweenISO(used, todayLocalDate) <= def.gracePeriodDays).length;
  return { currentLength: running, longestLength: longest, graceRemaining: Math.max(0, graceRemaining) };
}

const WINDOW_MS: Record<CriteriaDef["window"], number | null> = {
  daily: 24 * 60 * 60 * 1000,
  weekly: 7 * 24 * 60 * 60 * 1000,
  lifetime: null,
};

/** Progress toward a mission/badge criterion. `daily`/`weekly` are trailing
 * windows relative to `now` (not calendar-day/week boundaries) — a
 * deliberate simplification since per-user calendar boundaries would need
 * the same timezone plumbing as streaks; revisit if that distinction proves
 * to matter for a specific mission design. */
export function progressForCriteria(
  events: ActivityEventLite[],
  criteria: CriteriaDef,
  now: Date,
): ProgressResult {
  const windowMs = WINDOW_MS[criteria.window];
  const cutoff = windowMs === null ? null : new Date(now.getTime() - windowMs);
  const count =
    events.filter((e) => e.eventType === criteria.eventType && (cutoff === null || e.occurredAt >= cutoff))
      .length;
  return { count: Math.min(count, criteria.targetCount), target: criteria.targetCount };
}

/** For lifetime-window badges: the instant the cumulative count first hit
 * the target, or null if not yet earned. */
export function badgeEarnedAt(events: ActivityEventLite[], criteria: CriteriaDef): Date | null {
  const matching = events
    .filter((e) => e.eventType === criteria.eventType)
    .sort((a, b) => a.occurredAt.getTime() - b.occurredAt.getTime());
  if (matching.length < criteria.targetCount) return null;
  return matching[criteria.targetCount - 1].occurredAt;
}
