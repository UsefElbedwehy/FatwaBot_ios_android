// Production ConfigRepo backed by Supabase (service role, server-side only — ADR-0002).
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import type {
  AppContext,
  ConfigRepo,
  FeatureFlag,
  HomeLayout,
  LocaleInfo,
  PrayerDefaults,
  RemoteConfigEntry,
  StringPack,
  Theme,
} from "./types.ts";

export function supabaseClientFromEnv(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set");
  return createClient(url, key, { auth: { persistSession: false } });
}

export class SupabaseConfigRepo implements ConfigRepo {
  constructor(private readonly db: SupabaseClient) {}

  async remoteConfig(ctx: AppContext): Promise<RemoteConfigEntry[]> {
    const { data, error } = await this.db
      .schema("config").from("remote_config")
      .select("key,value,platform")
      .eq("app_id", ctx.appId)
      .in("platform", ["all", ctx.platform === "all" ? "all" : ctx.platform]);
    if (error) throw error;
    return (data ?? []).map((r) => ({ key: r.key, value: r.value }));
  }

  async featureFlags(ctx: AppContext): Promise<FeatureFlag[]> {
    const { data, error } = await this.db
      .schema("config").from("feature_flags")
      .select("key,enabled,rollout")
      .eq("app_id", ctx.appId);
    if (error) throw error;
    return data ?? [];
  }

  async enabledLocales(ctx: AppContext): Promise<LocaleInfo[]> {
    const { data, error } = await this.db
      .schema("config").from("locales")
      .select("locale,display_name,direction,digits,sort_order")
      .eq("app_id", ctx.appId)
      .eq("enabled", true)
      .order("sort_order");
    if (error) throw error;
    return (data ?? []).map(({ sort_order: _s, ...l }) => l as LocaleInfo);
  }

  async publishedTheme(ctx: AppContext): Promise<Theme | null> {
    const { data, error } = await this.db
      .schema("config").from("themes")
      .select("version,tokens")
      .eq("app_id", ctx.appId)
      .eq("published", true)
      .order("version", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw error;
    return data;
  }

  async publishedStringPack(
    ctx: AppContext,
    locale: string,
    sinceVersion: number | null,
  ): Promise<StringPack | null> {
    const { data, error } = await this.db
      .schema("config").from("string_packs")
      .select("locale,version,strings")
      .eq("app_id", ctx.appId)
      .eq("locale", locale)
      .eq("published", true)
      .order("version", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw error;
    if (!data) return null;
    if (sinceVersion !== null && data.version <= sinceVersion) return null; // client up to date
    return data;
  }

  async publishedHomeLayout(ctx: AppContext): Promise<HomeLayout | null> {
    // Platform-specific layout wins over 'all'.
    const { data, error } = await this.db
      .schema("config").from("home_layouts")
      .select("platform,version,sections")
      .eq("app_id", ctx.appId)
      .eq("published", true)
      .in("platform", ["all", ctx.platform === "all" ? "all" : ctx.platform])
      .order("version", { ascending: false });
    if (error) throw error;
    if (!data?.length) return null;
    const specific = data.find((l) => l.platform !== "all");
    const chosen = specific ?? data[0];
    return { version: chosen.version, sections: chosen.sections };
  }

  async prayerDefaults(ctx: AppContext, countryCode: string): Promise<PrayerDefaults> {
    const { data, error } = await this.db
      .schema("config").from("prayer_defaults")
      .select("country_code,method,params")
      .eq("app_id", ctx.appId)
      .in("country_code", [countryCode, "*"]);
    if (error) throw error;
    const rows = data ?? [];
    return rows.find((r) => r.country_code === countryCode) ??
      rows.find((r) => r.country_code === "*") ??
      { country_code: "*", method: "mwl", params: { madhab: "shafi" } };
  }
}
