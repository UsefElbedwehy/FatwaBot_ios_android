import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AppContext } from "./types.ts";
import type { AdminStringsRepo, StringPackSummary, StringPackVersion } from "./admin_strings_types.ts";

function toPack(row: Record<string, unknown>): StringPackVersion {
  return {
    locale: row.locale as string,
    version: Number(row.version),
    published: Boolean(row.published),
    strings: (row.strings ?? {}) as Record<string, string>,
  };
}

export class SupabaseAdminStringsRepo implements AdminStringsRepo {
  constructor(private readonly db: SupabaseClient) {}

  async listLocales(ctx: AppContext): Promise<StringPackSummary[]> {
    // Two passes on purpose: the version index is cheap, `strings` is not.
    // Pulling every historical pack just to count keys would ship every
    // superseded copy of the whole pack over the wire.
    const { data, error } = await this.db
      .schema("config").from("string_packs")
      .select("locale,version,published")
      .eq("app_id", ctx.appId);
    if (error) throw error;

    const byLocale = new Map<string, { published: number | null; draft: number | null; newest: number }>();
    for (const row of data ?? []) {
      const locale = row.locale as string;
      const version = Number(row.version);
      const acc = byLocale.get(locale) ?? { published: null, draft: null, newest: version };
      if (row.published) acc.published = Math.max(acc.published ?? version, version);
      else acc.draft = Math.max(acc.draft ?? version, version);
      acc.newest = Math.max(acc.newest, version);
      byLocale.set(locale, acc);
    }

    const summaries: StringPackSummary[] = [];
    for (const [locale, acc] of [...byLocale].sort(([a], [b]) => a.localeCompare(b))) {
      const newest = await this.getPack(ctx, locale, acc.newest);
      summaries.push({
        locale,
        publishedVersion: acc.published,
        draftVersion: acc.draft,
        keyCount: newest ? Object.keys(newest.strings).length : 0,
      });
    }
    return summaries;
  }

  async getPack(ctx: AppContext, locale: string, version: number | null): Promise<StringPackVersion | null> {
    let query = this.db
      .schema("config").from("string_packs")
      .select("locale,version,published,strings")
      .eq("app_id", ctx.appId)
      .eq("locale", locale);
    query = version === null
      ? query.order("version", { ascending: false }).limit(1)
      : query.eq("version", version);
    const { data, error } = await query.maybeSingle();
    if (error) throw error;
    return data ? toPack(data) : null;
  }

  async createVersion(
    ctx: AppContext,
    locale: string,
    strings: Record<string, string>,
    published: boolean,
  ): Promise<StringPackVersion> {
    // max over ALL rows, not just published ones — see admin_strings_types.ts.
    const { data: highest, error: highestError } = await this.db
      .schema("config").from("string_packs")
      .select("version")
      .eq("app_id", ctx.appId)
      .eq("locale", locale)
      .order("version", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (highestError) throw highestError;
    const nextVersion = (highest ? Number(highest.version) : 0) + 1;

    // Two operators saving at the same instant lose the race on the
    // (app_id, locale, version) primary key and get a 500; that is the correct
    // outcome — the loser must reload rather than have their write silently
    // land on top of the other's.
    const { data, error } = await this.db
      .schema("config").from("string_packs")
      .insert({ app_id: ctx.appId, locale, version: nextVersion, strings, published })
      .select("locale,version,published,strings")
      .single();
    if (error) throw error;
    return toPack(data);
  }

  async setPublished(
    ctx: AppContext,
    locale: string,
    version: number,
    published: boolean,
  ): Promise<StringPackVersion | null> {
    const { data, error } = await this.db
      .schema("config").from("string_packs")
      .update({ published })
      .eq("app_id", ctx.appId)
      .eq("locale", locale)
      .eq("version", version)
      .select("locale,version,published,strings")
      .maybeSingle();
    if (error) throw error;
    return data ? toPack(data) : null;
  }
}
