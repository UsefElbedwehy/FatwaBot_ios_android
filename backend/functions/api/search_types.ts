import type { AppContext } from "./types.ts";

export type SearchSource = "azkar" | "dua" | "hadith_collections" | "ai_fatwa" | "ai_hadith" | "ai_question";

export interface SearchHistoryEntry {
  id: string;
  source: SearchSource;
  queryText: string;
  locale: string;
  createdAt: Date;
}

/** docs/features/search-history.md. Per-user, own repo (not admin content). */
export interface SearchHistoryRepo {
  record(
    ctx: AppContext,
    userId: string,
    source: SearchSource,
    queryText: string,
    locale: string,
  ): Promise<SearchHistoryEntry>;
  list(
    ctx: AppContext,
    userId: string,
    source: SearchSource | null,
    limit: number,
    before: string | null,
  ): Promise<SearchHistoryEntry[]>;
  deleteOne(ctx: AppContext, userId: string, id: string): Promise<boolean>;
  deleteAll(ctx: AppContext, userId: string): Promise<void>;
}
