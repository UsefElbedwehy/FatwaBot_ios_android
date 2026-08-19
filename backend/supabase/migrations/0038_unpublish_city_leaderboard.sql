-- Retire the city leaderboard (client decision, 2026-08-10). Global and country
-- remain.
--
-- ## Why unpublish rather than delete
-- The board carries memberships and scores that people earned. Unpublishing
-- removes it from /v1/leaderboards — so it vanishes from both apps with no
-- client change — while leaving that history intact. Deleting the definition
-- would cascade the memberships away, and a decision to hide a board is not a
-- decision to destroy what users did on it.
--
-- Reversing this is a one-line update, which is the point.
update gamification.leaderboard_defs
   set published = false,
       updated_at = now()
 where key = 'consistency_city';
