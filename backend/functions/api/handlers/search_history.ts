// POST/GET/DELETE /v1/search-history (docs/features/search-history.md).
import { verifyAccessToken } from "../auth/jwt.ts";
import { apiError, json } from "../http.ts";
import type { AppContext } from "../types.ts";
import type { SearchHistoryRepo, SearchSource } from "../search_types.ts";

interface SearchHistoryDeps {
  searchHistory: SearchHistoryRepo;
  jwtSecret: string;
}

const VALID_SOURCES: SearchSource[] = [
  "azkar",
  "dua",
  "hadith_collections",
  "ai_fatwa",
  "ai_hadith",
  "ai_question",
];

function isValidSource(value: unknown): value is SearchSource {
  return typeof value === "string" && (VALID_SOURCES as string[]).includes(value);
}

async function requireUser(req: Request, jwtSecret: string): Promise<string | Response> {
  const header = req.headers.get("authorization");
  if (!header?.startsWith("Bearer ")) return apiError(401, "unauthorized", "Valid bearer token required");
  const claims = await verifyAccessToken(header.slice("Bearer ".length), jwtSecret);
  if (!claims) return apiError(401, "unauthorized", "Valid bearer token required");
  return claims.sub;
}

function toJson(e: { id: string; source: string; queryText: string; locale: string; createdAt: Date }) {
  return {
    id: e.id,
    source: e.source,
    query_text: e.queryText,
    locale: e.locale,
    created_at: e.createdAt.toISOString(),
  };
}

/** POST /v1/search-history */
export async function handleRecordSearch(
  ctx: AppContext,
  deps: SearchHistoryDeps,
  req: Request,
  body: unknown,
): Promise<Response> {
  const userOrError = await requireUser(req, deps.jwtSecret);
  if (userOrError instanceof Response) return userOrError;

  const b = (body as Record<string, unknown> | null) ?? {};
  if (!isValidSource(b.source)) {
    return apiError(400, "invalid_source", `source must be one of ${VALID_SOURCES.join(", ")}`);
  }
  if (typeof b.query_text !== "string" || b.query_text.trim().length === 0) {
    return apiError(400, "invalid_query", "query_text must be a non-empty string");
  }
  const locale = typeof b.locale === "string" && b.locale.length > 0 ? b.locale : "ar";

  const entry = await deps.searchHistory.record(ctx, userOrError, b.source, b.query_text, locale);
  return json(toJson(entry), 201);
}

/** GET /v1/search-history?source=&limit=&before= */
export async function handleListSearchHistory(
  ctx: AppContext,
  deps: SearchHistoryDeps,
  req: Request,
  url: URL,
): Promise<Response> {
  const userOrError = await requireUser(req, deps.jwtSecret);
  if (userOrError instanceof Response) return userOrError;

  const rawSource = url.searchParams.get("source");
  if (rawSource && !isValidSource(rawSource)) {
    return apiError(400, "invalid_source", `source must be one of ${VALID_SOURCES.join(", ")}`);
  }
  const source: SearchSource | null = rawSource && isValidSource(rawSource) ? rawSource : null;
  const limitParam = url.searchParams.get("limit");
  const limit = limitParam ? Number(limitParam) : 50;
  if (!Number.isInteger(limit) || limit <= 0 || limit > 200) {
    return apiError(400, "invalid_limit", "limit must be an integer between 1 and 200");
  }
  const before = url.searchParams.get("before");

  const entries = await deps.searchHistory.list(ctx, userOrError, source, limit, before);
  return json({ entries: entries.map(toJson) });
}

/** DELETE /v1/search-history/{id} */
export async function handleDeleteSearchEntry(
  ctx: AppContext,
  deps: SearchHistoryDeps,
  req: Request,
  id: string,
): Promise<Response> {
  const userOrError = await requireUser(req, deps.jwtSecret);
  if (userOrError instanceof Response) return userOrError;
  const deleted = await deps.searchHistory.deleteOne(ctx, userOrError, id);
  if (!deleted) return apiError(404, "not_found", `No search history entry ${id}`);
  return json({ deleted: true });
}

/** DELETE /v1/search-history — clear all */
export async function handleClearSearchHistory(
  ctx: AppContext,
  deps: SearchHistoryDeps,
  req: Request,
): Promise<Response> {
  const userOrError = await requireUser(req, deps.jwtSecret);
  if (userOrError instanceof Response) return userOrError;
  await deps.searchHistory.deleteAll(ctx, userOrError);
  return json({ cleared: true });
}
