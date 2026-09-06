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
import { SupabaseAdminStringsRepo } from "./supabase_admin_strings_repo.ts";
import { verifierFromEnv } from "./auth/provider_verify.ts";
import { SupabaseGamificationRepo } from "./supabase_gamification_repo.ts";
import { SupabaseAnalyticsRepo } from "./supabase_analytics_repo.ts";
import { SupabaseLeaderboardRepo } from "./supabase_leaderboard_repo.ts";
import { SupabaseSearchHistoryRepo } from "./supabase_search_repo.ts";
import { SupabaseDeliveryLogRepo, SupabaseNotificationPrefsRepo } from "./supabase_notification_repo.ts";
import { FcmSender, parseServiceAccount } from "./fcm_sender.ts";
import {
  SupabaseAnswerCacheRepo,
  SupabaseEmbeddingCacheRepo,
  SupabaseFatwaSearchRepo,
} from "./supabase_fatwa_repo.ts";
import { ClaudeAnswerProvider, VoyageEmbeddingProvider } from "./ai_search/providers.ts";
import { CachingEmbeddingProvider } from "./ai_search/embedding_cache.ts";
import { PRIMARY_APP_ID } from "./context.ts";

const client = supabaseClientFromEnv();
const jwtSecret = Deno.env.get("API_JWT_SECRET");
if (!jwtSecret) throw new Error("API_JWT_SECRET not set");

// Optional: the FCM sender only exists once the Firebase service account is
// provisioned as a secret; campaign dispatch returns 503 until then.
const fcmServiceAccount = Deno.env.get("FCM_SERVICE_ACCOUNT");
const pushSender = fcmServiceAccount ? new FcmSender(parseServiceAccount(fcmServiceAccount)) : undefined;

// Same optional-until-configured pattern as pushSender above: /v1/search
// 503s (docs/features/ai-search-m5.0-spec.md §Answer contract) until both
// VOYAGE_API_KEY and ANTHROPIC_API_KEY are provisioned as secrets — never
// silently falls back to the meaningless dev-stub embedder/answerer in
// production.
const voyageApiKey = Deno.env.get("VOYAGE_API_KEY");
const anthropicApiKey = Deno.env.get("ANTHROPIC_API_KEY");
// Read-through cached, so a question already asked never reaches Voyage. The
// key is on a free tier whose rate limit costs ~56s on a throttled call, and
// devotional questions repeat heavily across users — see 0044.
const embeddingProvider = voyageApiKey
  ? new CachingEmbeddingProvider(
    new VoyageEmbeddingProvider(voyageApiKey),
    new SupabaseEmbeddingCacheRepo(client),
    PRIMARY_APP_ID,
  )
  : undefined;
// ANSWER_JSON_MODE=schema forces the API's structured outputs instead of the
// default prompt-requested JSON — the escape hatch if prompt mode ever starts
// falling back too often (see AnswerJsonMode). Unset means prompt mode.
const answerJsonMode = Deno.env.get("ANSWER_JSON_MODE") === "schema" ? "schema" : "prompt";
const answerProvider = anthropicApiKey
  ? new ClaudeAnswerProvider(anthropicApiKey, { jsonMode: answerJsonMode })
  : undefined;

const deps = {
  repo: new SupabaseConfigRepo(client),
  identity: new SupabaseIdentityRepo(client),
  content: new SupabaseContentRepo(client),
  adminContent: new SupabaseAdminContentRepo(client),
  adminAuth: new SupabaseAdminAuthRepo(client),
  adminUsers: new SupabaseAdminUsersRepo(client),
  adminStrings: new SupabaseAdminStringsRepo(client),
  auditLog: new SupabaseAuditLogRepo(client),
  jwtSecret,
  // Real Apple/Google ID-token verification (signature via each provider's
  // JWKS + issuer/audience/expiry). Set AUTH_VERIFIER=dev to fall back to the
  // stub on a staging project.
  verifier: verifierFromEnv((key) => Deno.env.get(key)),
  gamification: new SupabaseGamificationRepo(client),
  analytics: new SupabaseAnalyticsRepo(client),
  leaderboard: new SupabaseLeaderboardRepo(client),
  searchHistory: new SupabaseSearchHistoryRepo(client),
  notificationPrefs: new SupabaseNotificationPrefsRepo(client),
  deliveryLog: new SupabaseDeliveryLogRepo(client),
  pushSender,
  fatwaSearch: new SupabaseFatwaSearchRepo(client),
  answerCache: new SupabaseAnswerCacheRepo(client),
  embeddingProvider,
  answerProvider,
};

Deno.serve((req) => route(req, deps));
