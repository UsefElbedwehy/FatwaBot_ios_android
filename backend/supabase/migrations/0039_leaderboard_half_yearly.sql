-- 0039: leaderboards run on a 6-month cycle (owner decision, 2026-08-10) — the
-- admin honours a winner and gives a prize at the end of each half.
--
-- ## Why a new period type rather than `seasonal`
-- `seasonal` already exists and the engine already supports it, but it needs
-- an admin to set `season_starts_at`/`season_ends_at` by hand, and nothing
-- rolls those dates forward — a `seasonal` board just stops accumulating once
-- `season_ends_at` passes until someone remembers to edit it again. A prize
-- cycle that repeats "every 6 months" forever should not depend on that.
--
-- `halfyearly` is the same idea as the existing `weekly`/`monthly` periods
-- instead: a pure function of the current date (calendar halves, Jan-Jun and
-- Jul-Dec, UTC), computed in leaderboard_periods.ts. It rolls to the next half
-- on its own — no admin action, no cron, nothing to forget.
--
-- Constraint name confirmed against the live database
-- (pg_constraint / leaderboard_defs_period_check) rather than assumed.
alter table gamification.leaderboard_defs
    drop constraint leaderboard_defs_period_check;
alter table gamification.leaderboard_defs
    add constraint leaderboard_defs_period_check
    check (period in ('weekly', 'monthly', 'halfyearly', 'seasonal', 'lifetime', 'challenge'));

-- Only the two live boards move. `consistency_city` stays unpublished
-- (0038) and untouched — nothing to compete for on a board nobody sees.
update gamification.leaderboard_defs
   set period = 'halfyearly',
       updated_at = now()
 where key in ('consistency_global', 'consistency_country');
