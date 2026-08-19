-- 0027: make the country/city leaderboards actually local.
--
-- 0009 gave `leaderboard_defs.scope` three values (global/country/city) and
-- stored an opt-in `city` on membership, but nothing ever *used* either one:
-- `handleRecomputeSnapshot` ranked every member of a key together and
-- `handleListLeaderboards` served that whole snapshot to everyone. So the
-- "city" board ranked a user in Cairo against a user in Jakarta, and the
-- "country" board had no country to rank by at all — both were the global
-- board wearing a different name.
--
-- Two additions make scope real:
--   1. `country` on membership, so a country board has something to group by.
--   2. `bucket` on snapshots, so ranks are computed and served *within* a
--      region rather than across all of them.
--
-- `bucket` is the empty string for global boards rather than null: it is part
-- of the lookup key on every read, and null would silently drop those rows from
-- any equality filter.

alter table gamification.leaderboard_memberships
    add column if not exists country text;

alter table gamification.leaderboard_snapshots
    add column if not exists bucket text not null default '';

-- Ranks are per (board, period, bucket). The existing unique on
-- (app_id, leaderboard_key, period_key, user_id) still holds — a user belongs
-- to exactly one bucket per board — so it is left alone.
drop index if exists gamification.leaderboard_snapshots_lookup_idx;
create index if not exists leaderboard_snapshots_lookup_idx
    on gamification.leaderboard_snapshots (app_id, leaderboard_key, period_key, bucket);

create index if not exists leaderboard_memberships_region_idx
    on gamification.leaderboard_memberships (app_id, leaderboard_key, country, city);

comment on column gamification.leaderboard_memberships.country is
    'ISO 3166-1 alpha-2, uppercased. Captured only when the user joins a country-scope board (opt-in, same rule as city).';
comment on column gamification.leaderboard_snapshots.bucket is
    'Region the rank is relative to: empty for global, country code for country scope, city name for city scope.';
