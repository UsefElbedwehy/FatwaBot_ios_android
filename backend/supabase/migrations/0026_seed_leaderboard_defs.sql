-- 0026: seed the leaderboard definitions.
--
-- Same failure mode migration 0012 fixed for streaks/missions/badges, and for
-- the same reason: `supabase db push` never runs seed.sql, so
-- `gamification.leaderboard_defs` was empty in every environment. The tables,
-- the router (`GET /v1/leaderboards`, join/leave, admin recompute) and the
-- scoring engine have all existed since M3 — with zero rows the endpoint
-- returned `[]` and the feature was dead on arrival, exactly the way Journey
-- was before 0012.
--
-- Three boards, one per scope the schema already allows (global / country /
-- city). All three share one metric so a user's standing means the same thing
-- on each; only the peer group changes.
--
-- ## What is being ranked, and why not raw worship
-- ADR-0007's riya' guardrail and ADR-0012 both say: rank *consistency*, never
-- worship volume. Every term is therefore capped per period — the cap, not the
-- weight, is what stops "who prayed the most" from becoming the game. A user
-- who keeps their four fixed awrad and reads a hadith most days tops out; doing
-- ten times as much earns nothing extra.
--
-- `fixed_wird_completed` is the currency rather than `wird_day_completed`
-- (owner decision, 2026-07). Day-completion is all-or-nothing over *every*
-- active wird, so a user with one trivial custom wird earns it more easily than
-- a user with ten — it is not comparable between users. The four fixed slots
-- are on every board by construction, which is what makes them comparable.
-- Custom awrad stay in the app for personal practice and are deliberately
-- unranked. The scoring engine filters on event type alone (it cannot read
-- event metadata), which is why the clients emit a distinct event.
--
-- Idempotent: re-running is a no-op.

with board(key, scope, name_ar, name_en) as (
    values
        ('consistency_global', 'global',  'الترتيب العام',   'Global'),
        ('consistency_country', 'country', 'ترتيب بلدك',      'Your country'),
        ('consistency_city',   'city',    'ترتيب مدينتك',    'Your city')
)
insert into gamification.leaderboard_defs
    (key, name_translations, scope, period, metric, tie_breakers,
     visibility, display_requirements, rewards_translations, enabled, published)
select
    board.key,
    jsonb_build_object('ar', board.name_ar, 'en', board.name_en),
    board.scope,
    'weekly',
    -- Caps are per period (weekly). 4 fixed slots x 7 days = 28 is a perfect
    -- week, so the cap is the ceiling rather than a throttle; hadith and azkar
    -- are capped well below what a determined user could do, on purpose.
    '{"terms": [
        {"event_type": "fixed_wird_completed",       "weight": 10, "cap_per_period": 28},
        {"event_type": "azkar_completed",            "weight": 5,  "cap_per_period": 14},
        {"event_type": "hadith_entry_read",          "weight": 2,  "cap_per_period": 20},
        {"event_type": "tasbeeh_session_completed",  "weight": 2,  "cap_per_period": 14}
     ]}'::jsonb,
    -- Higher wins, in order. Fixed awrad first so a tie breaks toward the user
    -- who kept the harder, every-single-day commitment.
    array['fixed_wird_completed', 'azkar_completed'],
    -- Opt-in only, for all three. A leaderboard nobody agreed to join is
    -- precisely the riya' risk ADR-0007 exists to avoid, and the city board
    -- additionally implies sharing where you are.
    'opt_in_only',
    '{"requires_published_name": false}'::jsonb,
    '{"ar": "ثبّتك الله", "en": "May Allah keep you steadfast"}'::jsonb,
    true,
    true
from board
on conflict (app_id, key) do nothing;
