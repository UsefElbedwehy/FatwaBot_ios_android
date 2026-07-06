import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AppContext } from "./types.ts";
import type { SearchHistoryEntry, SearchHistoryRepo, SearchSource } from "./search_types.ts";

function toEntry(row: Record<string, unknown>): SearchHistoryEntry {
  return {
    id: row.id as string,
    source: row.source as SearchSource,
    queryText: row.query_text as string,
    locale: row.locale as string,
    createdAt: new Date(row.created_at as string),
  };
}

export class SupabaseSearchHistoryRepo implements SearchHistoryRepo {
  constructor(private readonly db: SupabaseClient) {}

  async record(
    ctx: AppContext,
    userId: string,
    source: SearchSource,
    queryText: string,
    locale: string,
  ): Promise<SearchHistoryEntry> {
    const { data, error } = await this.db
      .schema("search").from("history")
      .insert({ app_id: ctx.appId, user_id: userId, source, query_text: queryText, locale })
      .select("*")
      .single();
    if (error) throw error;
    return toEntry(data);
  }

  async list(
    ctx: AppContext,
    userId: string,
    source: SearchSource | null,
    limit: number,
    before: string | null,
  ): Promise<SearchHistoryEntry[]> {
    let query = this.db
      .schema("search").from("history")
      .select("*")
      .eq("app_id", ctx.appId).eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(limit);
    if (source) query = query.eq("source", source);
    if (before) query = query.lt("created_at", before);
    const { data, error } = await query;
    if (error) throw error;
    return (data ?? []).map(toEntry);
  }

  async deleteOne(ctx: AppContext, userId: string, id: string): Promise<boolean> {
    const { data, error } = await this.db
      .schema("search").from("history")
      .delete()
      .eq("app_id", ctx.appId).eq("user_id", userId).eq("id", id)
      .select("id");
    if (error) throw error;
    return (data?.length ?? 0) > 0;
  }

  async deleteAll(ctx: AppContext, userId: string): Promise<void> {
    const { error } = await this.db
      .schema("search").from("history")
      .delete()
      .eq("app_id", ctx.appId).eq("user_id", userId);
    if (error) throw error;
  }
}
