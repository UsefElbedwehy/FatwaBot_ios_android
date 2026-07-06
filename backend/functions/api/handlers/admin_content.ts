import { apiError, json } from "../http.ts";
import type { AppContext } from "../types.ts";
import { ADMIN_COLLECTIONS } from "../admin_types.ts";
import type { AdminContentRepo, AuditLogRepo } from "../admin_types.ts";

function isKnownCollection(collection: string): boolean {
  return Object.hasOwn(ADMIN_COLLECTIONS, collection);
}

/** GET /admin/v1/content/{collection} */
export async function handleListContent(
  ctx: AppContext,
  repo: AdminContentRepo,
  collection: string,
): Promise<Response> {
  if (!isKnownCollection(collection)) {
    return apiError(404, "unknown_collection", `Unknown collection: ${collection}`);
  }
  return json({ rows: await repo.list(ctx, collection) });
}

/** POST /admin/v1/content/{collection} */
export async function handleCreateContent(
  ctx: AppContext,
  repo: AdminContentRepo,
  audit: AuditLogRepo,
  adminId: string,
  collection: string,
  body: unknown,
): Promise<Response> {
  if (!isKnownCollection(collection)) {
    return apiError(404, "unknown_collection", `Unknown collection: ${collection}`);
  }
  if (typeof body !== "object" || body === null) {
    return apiError(400, "invalid_body", "Request body must be a JSON object of fields");
  }
  const row = await repo.create(ctx, collection, body as Record<string, unknown>);
  await audit.record(ctx, {
    adminId,
    collection,
    rowId: row.id,
    action: "create",
    before: null,
    after: row.fields,
  });
  return json(row, 201);
}

/** PATCH /admin/v1/content/{collection}/{id} */
export async function handleUpdateContent(
  ctx: AppContext,
  repo: AdminContentRepo,
  audit: AuditLogRepo,
  adminId: string,
  collection: string,
  id: string,
  body: unknown,
): Promise<Response> {
  if (!isKnownCollection(collection)) {
    return apiError(404, "unknown_collection", `Unknown collection: ${collection}`);
  }
  if (typeof body !== "object" || body === null) {
    return apiError(400, "invalid_body", "Request body must be a JSON object of fields");
  }
  const before = (await repo.list(ctx, collection)).find((r) => r.id === id) ?? null;
  const row = await repo.update(ctx, collection, id, body as Record<string, unknown>);
  if (!row) return apiError(404, "not_found", `No row ${id} in ${collection}`);
  await audit.record(ctx, {
    adminId,
    collection,
    rowId: id,
    action: "update",
    before: before?.fields ?? null,
    after: row.fields,
  });
  return json(row);
}

/** POST /admin/v1/content/{collection}/{id}/publish|unpublish */
export async function handleSetPublished(
  ctx: AppContext,
  repo: AdminContentRepo,
  audit: AuditLogRepo,
  adminId: string,
  collection: string,
  id: string,
  published: boolean,
): Promise<Response> {
  if (!isKnownCollection(collection)) {
    return apiError(404, "unknown_collection", `Unknown collection: ${collection}`);
  }
  const before = (await repo.list(ctx, collection)).find((r) => r.id === id) ?? null;
  const row = await repo.setPublished(ctx, collection, id, published);
  if (!row) return apiError(404, "not_found", `No row ${id} in ${collection}`);
  await audit.record(ctx, {
    adminId,
    collection,
    rowId: id,
    action: published ? "publish" : "unpublish",
    before: before?.fields ?? null,
    after: row.fields,
  });
  return json(row);
}

/** GET /admin/v1/audit-log?collection= */
export async function handleListAuditLog(
  ctx: AppContext,
  audit: AuditLogRepo,
  collection: string | null,
): Promise<Response> {
  return json({ entries: await audit.list(ctx, collection ?? undefined) });
}
