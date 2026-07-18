import { apiError, json } from "../http.ts";
import type { AppContext } from "../types.ts";
import type { AdminUsersRepo } from "../admin_types.ts";

/** GET /admin/v1/users?query=&limit=&before= */
export async function handleListUsers(
  ctx: AppContext,
  repo: AdminUsersRepo,
  query: string | null,
  limitParam: string | null,
  beforeParam: string | null,
): Promise<Response> {
  const limit = limitParam ? Number(limitParam) : 50;
  if (!Number.isInteger(limit) || limit < 1 || limit > 200) {
    return apiError(400, "invalid_limit", "limit must be an integer between 1 and 200");
  }
  const before = beforeParam ? Number(beforeParam) : null;
  if (before !== null && !Number.isFinite(before)) {
    return apiError(400, "invalid_before", "before must be an epoch-seconds number");
  }
  return json({ users: await repo.list(ctx, query, limit, before) });
}
