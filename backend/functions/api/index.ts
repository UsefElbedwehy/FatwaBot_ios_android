// API gateway entrypoint (Supabase Edge Function "api").
// All client traffic: /functions/v1/api/v1/... — see router.ts.
import { route } from "./router.ts";
import { supabaseClientFromEnv, SupabaseConfigRepo } from "./supabase_repo.ts";
import { SupabaseIdentityRepo } from "./supabase_identity_repo.ts";
import { SupabaseContentRepo } from "./supabase_content_repo.ts";

const client = supabaseClientFromEnv();
const jwtSecret = Deno.env.get("API_JWT_SECRET");
if (!jwtSecret) throw new Error("API_JWT_SECRET not set");

const deps = {
  repo: new SupabaseConfigRepo(client),
  identity: new SupabaseIdentityRepo(client),
  content: new SupabaseContentRepo(client),
  jwtSecret,
};

Deno.serve((req) => route(req, deps));
