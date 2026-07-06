// Pure leaderboard scoring/ranking logic (docs/features/leaderboard.md,
// ADR-0012). Ranks consistency (streak/challenge activity), never raw
// worship volume, per ADR-0007's guardrail against riya'.
import type { ActivityEventLite } from "./gamification_engine.ts";

export interface ScoreTerm {
  eventType: string;
  weight: number;
  capPerPeriod: number;
}

export interface LeaderboardMetric {
  terms: ScoreTerm[];
}

/** Weighted, capped sum over the given window (docs/features/leaderboard.md's
 * constrained declarative form — no arbitrary code, always recomputable). */
export function computeScore(
  events: ActivityEventLite[],
  metric: LeaderboardMetric,
  windowStart: Date | null,
  windowEnd: Date | null,
): number {
  let score = 0;
  for (const term of metric.terms) {
    const count = events.filter((e) =>
      e.eventType === term.eventType &&
      (windowStart === null || e.occurredAt >= windowStart) &&
      (windowEnd === null || e.occurredAt <= windowEnd)
    ).length;
    score += term.weight * Math.min(count, term.capPerPeriod);
  }
  return score;
}

export interface ScoredEntry {
  userId: string;
  score: number;
  /** One value per configured tie-breaker, in priority order — higher wins. */
  tieBreakValues: number[];
}

export interface RankedEntry extends ScoredEntry {
  rank: number;
}

/** Sorts by score desc, then tie-breakers in order (each higher-wins). Ties
 * that remain after all tie-breakers get sequential ranks (not a shared
 * rank number) — a defensible simplification; dense ranking is a UI nicety,
 * not a correctness requirement. */
export function rankEntries(entries: ScoredEntry[]): RankedEntry[] {
  const sorted = [...entries].sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    const len = Math.max(a.tieBreakValues.length, b.tieBreakValues.length);
    for (let i = 0; i < len; i++) {
      const av = a.tieBreakValues[i] ?? 0;
      const bv = b.tieBreakValues[i] ?? 0;
      if (bv !== av) return bv - av;
    }
    return 0;
  });
  return sorted.map((e, i) => ({ ...e, rank: i + 1 }));
}
