import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AppContext } from "./types.ts";
import {
  ADMIN_COLLECTIONS,
  type AdminAuthRepo,
  type AdminContentRepo,
  type AdminContentRow,
  type AdminUserRow,
  type AdminUsersRepo,
  type AuditEntry,
  type AuditLogRepo,
} from "./admin_types.ts";

function toAdminRow(row: Record<string, unknown>): AdminContentRow {
  const { id, published, version, app_id: _appId, updated_at: _updatedAt, ...fields } = row;
  return { id: id as string, published: Boolean(published), version: Number(version), fields };
}

export class SupabaseAdminContentRepo implements AdminContentRepo {
  constructor(private readonly db: SupabaseClient) {}

  async list(ctx: AppContext, collection: string): Promise<AdminContentRow[]> {
    const ref = ADMIN_COLLECTIONS[collection];
    const { data, error } = await this.db
      .schema(ref.schema).from(ref.table)
      .select("*")
      .eq("app_id", ctx.appId);
    if (error) throw error;
    return (data ?? []).map(toAdminRow);
  }

  async create(
    ctx: AppContext,
    collection: string,
    fields: Record<string, unknown>,
  ): Promise<AdminContentRow> {
    const ref = ADMIN_COLLECTIONS[collection];
    const { data, error } = await this.db
      .schema(ref.schema).from(ref.table)
      .insert({ ...fields, app_id: ctx.appId, published: false, version: 1 })
      .select("*")
      .single();
    if (error) throw error;
    return toAdminRow(data);
  }

  async update(
    ctx: AppContext,
    collection: string,
    id: string,
    fields: Record<string, unknown>,
  ): Promise<AdminContentRow | null> {
    const ref = ADMIN_COLLECTIONS[collection];
    const { data: existing, error: fetchError } = await this.db
      .schema(ref.schema).from(ref.table)
      .select("published,version")
      .eq("app_id", ctx.appId).eq("id", id)
      .maybeSingle();
    if (fetchError) throw fetchError;
    if (!existing) return null;

    const versionBump = existing.published ? { version: existing.version + 1 } : {};
    const { data, error } = await this.db
      .schema(ref.schema).from(ref.table)
      .update({ ...fields, ...versionBump, updated_at: new Date().toISOString() })
      .eq("app_id", ctx.appId).eq("id", id)
      .select("*")
      .single();
    if (error) throw error;
    return toAdminRow(data);
  }

  async setPublished(
    ctx: AppContext,
    collection: string,
    id: string,
    published: boolean,
  ): Promise<AdminContentRow | null> {
    const ref = ADMIN_COLLECTIONS[collection];
    const { data, error } = await this.db
      .schema(ref.schema).from(ref.table)
      .update({ published, updated_at: new Date().toISOString() })
      .eq("app_id", ctx.appId).eq("id", id)
      .select("*")
      .maybeSingle();
    if (error) throw error;
    return data ? toAdminRow(data) : null;
  }
}

function toAdminUserRow(row: Record<string, unknown>): AdminUserRow {
  return {
    id: row.id as string,
    kind: row.kind as AdminUserRow["kind"],
    provider: row.provider as AdminUserRow["provider"],
    displayName: (row.display_name as string | null) ?? null,
    countryCode: (row.country_code as string | null) ?? null,
    createdAtEpochSeconds: Math.floor(new Date(row.created_at as string).getTime() / 1000),
    linkedAtEpochSeconds: row.linked_at ? Math.floor(new Date(row.linked_at as string).getTime() / 1000) : null,
  };
}

export class SupabaseAdminUsersRepo implements AdminUsersRepo {
  constructor(private readonly db: SupabaseClient) {}

  async list(
    ctx: AppContext,
    query: string | null,
    limit: number,
    before: number | null,
  ): Promise<AdminUserRow[]> {
    let q = this.db
      .schema("identity").from("users")
      .select("id,kind,provider,display_name,country_code,created_at,linked_at")
      .eq("app_id", ctx.appId)
      .order("created_at", { ascending: false })
      .limit(limit);
    const isUuid = query !== null && /^[0-9a-f-]{36}$/i.test(query);
    if (query && isUuid) {
      q = q.or(`display_name.ilike.%${query}%,id.eq.${query}`);
    } else if (query) {
      q = q.ilike("display_name", `%${query}%`);
    }
    if (before !== null) q = q.lt("created_at", new Date(before * 1000).toISOString());
    const { data, error } = await q;
    if (error) throw error;
    return (data ?? []).map(toAdminUserRow);
  }
}

export class SupabaseAdminAuthRepo implements AdminAuthRepo {
  constructor(private readonly db: SupabaseClient) {}

  async findAdminByEmail(
    ctx: AppContext,
    email: string,
  ): Promise<{ id: string; passwordHash: string } | null> {
    const { data, error } = await this.db
      .schema("admin").from("admin_users")
      .select("id,password_hash")
      .eq("app_id", ctx.appId).eq("email", email)
      .maybeSingle();
    if (error) throw error;
    return data ? { id: data.id, passwordHash: data.password_hash } : null;
  }
}

export class SupabaseAuditLogRepo implements AuditLogRepo {
  constructor(private readonly db: SupabaseClient) {}

  async record(ctx: AppContext, entry: AuditEntry): Promise<void> {
    const { error } = await this.db
      .schema("admin").from("audit_log")
      .insert({
        app_id: ctx.appId,
        admin_id: entry.adminId,
        collection: entry.collection,
        row_id: entry.rowId,
        action: entry.action,
        before: entry.before,
        after: entry.after,
      });
    if (error) throw error;
  }

  async list(
    ctx: AppContext,
    collection?: string,
  ): Promise<(AuditEntry & { createdAtEpochSeconds: number })[]> {
    let query = this.db
      .schema("admin").from("audit_log")
      .select("*")
      .eq("app_id", ctx.appId)
      .order("created_at", { ascending: false });
    if (collection) query = query.eq("collection", collection);
    const { data, error } = await query;
    if (error) throw error;
    return (data ?? []).map((r) => ({
      adminId: r.admin_id,
      collection: r.collection,
      rowId: r.row_id,
      action: r.action,
      before: r.before,
      after: r.after,
      createdAtEpochSeconds: Math.floor(new Date(r.created_at).getTime() / 1000),
    }));
  }
}
