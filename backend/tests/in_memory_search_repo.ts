import type { AppContext } from "../functions/api/types.ts";
import type { SearchHistoryEntry, SearchHistoryRepo, SearchSource } from "../functions/api/search_types.ts";

let counter = 0;
function nextId(): string {
  counter += 1;
  return `search-${counter.toString().padStart(4, "0")}`;
}

export class InMemorySearchHistoryRepo implements SearchHistoryRepo {
  private byUser = new Map<string, (SearchHistoryEntry & { seq: number })[]>();
  private seqCounter = 0;

  record(
    _ctx: AppContext,
    userId: string,
    source: SearchSource,
    queryText: string,
    locale: string,
  ): Promise<SearchHistoryEntry> {
    this.seqCounter += 1;
    const entry = { id: nextId(), source, queryText, locale, createdAt: new Date(), seq: this.seqCounter };
    const list = this.byUser.get(userId) ?? [];
    list.push(entry);
    this.byUser.set(userId, list);
    return Promise.resolve(entry);
  }

  list(
    _ctx: AppContext,
    userId: string,
    source: SearchSource | null,
    limit: number,
    before: string | null,
  ): Promise<SearchHistoryEntry[]> {
    // Break same-millisecond createdAt ties with insertion order (seq) —
    // real Postgres timestamps are far less likely to tie, but this keeps
    // fast-executing tests deterministic.
    let entries = [...(this.byUser.get(userId) ?? [])].sort((a, b) => b.seq - a.seq);
    if (source) entries = entries.filter((e) => e.source === source);
    if (before) {
      const cutoff = new Date(before).getTime();
      entries = entries.filter((e) => e.createdAt.getTime() < cutoff);
    }
    return Promise.resolve(entries.slice(0, limit));
  }

  deleteOne(_ctx: AppContext, userId: string, id: string): Promise<boolean> {
    const list = this.byUser.get(userId) ?? [];
    const index = list.findIndex((e) => e.id === id);
    if (index === -1) return Promise.resolve(false);
    list.splice(index, 1);
    return Promise.resolve(true);
  }

  deleteAll(_ctx: AppContext, userId: string): Promise<void> {
    this.byUser.set(userId, []);
    return Promise.resolve();
  }
}
