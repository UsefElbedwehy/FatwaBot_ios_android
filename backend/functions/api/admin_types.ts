import type { AppContext } from "./types.ts";

/** Generic admin-visible row (draft + published) — mirror of docs/features/admin-dashboard-v1.md.
 * All content tables share this shape at the SQL level (id, ...fields, version, published). */
export interface AdminContentRow {
  id: string;
  published: boolean;
  version: number;
  fields: Record<string, unknown>;
}

export type AdminAction = "create" | "update" | "publish" | "unpublish";

export interface AuditEntry {
  adminId: string;
  collection: string;
  rowId: string;
  action: AdminAction;
  before: Record<string, unknown> | null;
  after: Record<string, unknown> | null;
}

export interface AdminCollectionRef {
  schema: string;
  table: string;
}

/** Whitelisted collection slugs → (Postgres schema, table) (ADR-0009: no
 * arbitrary table access from admin input). Gamification/leaderboard/
 * notification definitions (M3) reuse this exact CRUD mechanism — they're
 * admin-authored draft/publish data with the same shape as content rows,
 * just living in a different schema (docs/features/gamification.md). */
export const ADMIN_COLLECTIONS: Record<string, AdminCollectionRef> = {
  "azkar-categories": { schema: "content", table: "azkar_categories" },
  "azkar-items": { schema: "content", table: "azkar_items" },
  "dua-categories": { schema: "content", table: "dua_categories" },
  "duas": { schema: "content", table: "duas" },
  "hadith-collections": { schema: "content", table: "hadith_collections" },
  "hadith-entries": { schema: "content", table: "hadith_entries" },
  "wird-templates": { schema: "content", table: "wird_templates" },
  "streak-defs": { schema: "gamification", table: "streak_defs" },
  "missions": { schema: "gamification", table: "missions" },
  "badges": { schema: "gamification", table: "badges" },
  "leaderboard-defs": { schema: "gamification", table: "leaderboard_defs" },
  "notification-types": { schema: "config", table: "notification_types" },
  "notification-templates": { schema: "notifications", table: "templates" },
  "notification-campaigns": { schema: "notifications", table: "campaigns" },
};

export interface AdminContentRepo {
  list(ctx: AppContext, collection: string): Promise<AdminContentRow[]>;
  create(ctx: AppContext, collection: string, fields: Record<string, unknown>): Promise<AdminContentRow>;
  /** Bumps `version` only when the row is already published (draft edits don't bump). */
  update(
    ctx: AppContext,
    collection: string,
    id: string,
    fields: Record<string, unknown>,
  ): Promise<AdminContentRow | null>;
  setPublished(
    ctx: AppContext,
    collection: string,
    id: string,
    published: boolean,
  ): Promise<AdminContentRow | null>;
}

export interface AdminAuthRepo {
  findAdminByEmail(ctx: AppContext, email: string): Promise<{ id: string; passwordHash: string } | null>;
}

export interface AuditLogRepo {
  record(ctx: AppContext, entry: AuditEntry): Promise<void>;
  list(ctx: AppContext, collection?: string): Promise<(AuditEntry & { createdAtEpochSeconds: number })[]>;
}
