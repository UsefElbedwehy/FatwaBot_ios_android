// API gateway entrypoint (Supabase Edge Function "api").
// All client traffic: /functions/v1/api/v1/... — see router.ts.
import { route } from "./router.ts";
import { supabaseClientFromEnv, SupabaseConfigRepo } from "./supabase_repo.ts";

const repo = new SupabaseConfigRepo(supabaseClientFromEnv());

Deno.serve((req) => route(req, { repo }));
