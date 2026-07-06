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

/** Whitelisted collection slugs → content-schema table names (ADR-0009: no
 * arbitrary table access from admin input). */
export const ADMIN_COLLECTIONS: Record<string, string> = {
  "azkar-categories": "azkar_categories",
  "azkar-items": "azkar_items",
  "dua-categories": "dua_categories",
  "duas": "duas",
  "hadith-collections": "hadith_collections",
  "hadith-entries": "hadith_entries",
  "wird-templates": "wird_templates",
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
