// API gateway entrypoint (Supabase Edge Function "api").
// Mobile traffic: /functions/v1/api/v1/...; dashboard traffic:
// /functions/v1/api/admin/v1/... (ADR-0009) — see router.ts.
import { route } from "./router.ts";
import { supabaseClientFromEnv, SupabaseConfigRepo } from "./supabase_repo.ts";
import { SupabaseIdentityRepo } from "./supabase_identity_repo.ts";
import { SupabaseContentRepo } from "./supabase_content_repo.ts";
import {
  SupabaseAdminAuthRepo,
  SupabaseAdminContentRepo,
  SupabaseAdminUsersRepo,
  SupabaseAuditLogRepo,
} from "./supabase_admin_repo.ts";
import { DevIdentityProviderVerifier } from "./auth/provider_verify.ts";
import { SupabaseGamificationRepo } from "./supabase_gamification_repo.ts";
import { SupabaseLeaderboardRepo } from "./supabase_leaderboard_repo.ts";
import { SupabaseSearchHistoryRepo } from "./supabase_search_repo.ts";
import { SupabaseDeliveryLogRepo, SupabaseNotificationPrefsRepo } from "./supabase_notification_repo.ts";
import { FcmSender, parseServiceAccount } from "./fcm_sender.ts";

const client = supabaseClientFromEnv();
const jwtSecret = Deno.env.get("API_JWT_SECRET");
if (!jwtSecret) throw new Error("API_JWT_SECRET not set");

// Optional: the FCM sender only exists once the Firebase service account is
// provisioned as a secret; campaign dispatch returns 503 until then.
const fcmServiceAccount = Deno.env.get("FCM_SERVICE_ACCOUNT");
const pushSender = fcmServiceAccount
  ? new FcmSender(parseServiceAccount(fcmServiceAccount))
  : undefined;

const deps = {
  repo: new SupabaseConfigRepo(client),
  identity: new SupabaseIdentityRepo(client),
  content: new SupabaseContentRepo(client),
  adminContent: new SupabaseAdminContentRepo(client),
  adminAuth: new SupabaseAdminAuthRepo(client),
  adminUsers: new SupabaseAdminUsersRepo(client),
  auditLog: new SupabaseAuditLogRepo(client),
  jwtSecret,
  // docs/features/accounts.md: swap for real Apple/Google JWKS verification
  // once Q8's OAuth credentials are provisioned — no contract change needed.
  verifier: new DevIdentityProviderVerifier(),
  gamification: new SupabaseGamificationRepo(client),
  leaderboard: new SupabaseLeaderboardRepo(client),
  searchHistory: new SupabaseSearchHistoryRepo(client),
  notificationPrefs: new SupabaseNotificationPrefsRepo(client),
  deliveryLog: new SupabaseDeliveryLogRepo(client),
  pushSender,
};

Deno.serve((req) => route(req, deps));
