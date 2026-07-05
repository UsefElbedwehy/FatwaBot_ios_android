import { apiError, json } from "../http.ts";
import type { AppContext } from "../types.ts";
import type { ContentRepo } from "../content_types.ts";

const CACHE_CONTENT = { "cache-control": "public, max-age=600" };

function upToDateOr<T extends { version: number }>(
  data: T,
  sinceVersion: number | null,
): Response {
  if (sinceVersion !== null && data.version <= sinceVersion) {
    return json({ up_to_date: true }, 200, CACHE_CONTENT);
  }
  return json(data, 200, CACHE_CONTENT);
}

function parseSinceVersion(raw: string | null): number | null | "invalid" {
  if (raw === null) return null;
  const value = Number(raw);
  return Number.isInteger(value) ? value : "invalid";
}

/** GET /v1/content/azkar?since_version= */
export async function handleAzkarCollection(
  ctx: AppContext,
  repo: ContentRepo,
  sinceVersionRaw: string | null,
): Promise<Response> {
  const sinceVersion = parseSinceVersion(sinceVersionRaw);
  if (sinceVersion === "invalid") {
    return apiError(400, "invalid_since_version", "since_version must be an integer");
  }
  return upToDateOr(await repo.azkarCollection(ctx), sinceVersion);
}

/** GET /v1/content/duas?since_version= */
export async function handleDuaCollection(
  ctx: AppContext,
  repo: ContentRepo,
  sinceVersionRaw: string | null,
): Promise<Response> {
  const sinceVersion = parseSinceVersion(sinceVersionRaw);
  if (sinceVersion === "invalid") {
    return apiError(400, "invalid_since_version", "since_version must be an integer");
  }
  return upToDateOr(await repo.duaCollection(ctx), sinceVersion);
}

/** GET /v1/content/hadith-collections — lightweight summaries, no entries. */
export async function handleHadithCollections(ctx: AppContext, repo: ContentRepo): Promise<Response> {
  const collections = await repo.hadithCollections(ctx);
  return json({ collections }, 200, CACHE_CONTENT);
}

/** GET /v1/content/hadith-collections/{slug}?since_version= */
export async function handleHadithCollectionDetail(
  ctx: AppContext,
  repo: ContentRepo,
  slug: string,
  sinceVersionRaw: string | null,
): Promise<Response> {
  const sinceVersion = parseSinceVersion(sinceVersionRaw);
  if (sinceVersion === "invalid") {
    return apiError(400, "invalid_since_version", "since_version must be an integer");
  }
  const detail = await repo.hadithCollectionDetail(ctx, slug);
  if (!detail) return apiError(404, "collection_not_found", `Unknown collection: ${slug}`);
  return upToDateOr(detail, sinceVersion);
}

/** GET /v1/content/wird-templates?since_version= */
export async function handleWirdTemplates(
  ctx: AppContext,
  repo: ContentRepo,
  sinceVersionRaw: string | null,
): Promise<Response> {
  const sinceVersion = parseSinceVersion(sinceVersionRaw);
  if (sinceVersion === "invalid") {
    return apiError(400, "invalid_since_version", "since_version must be an integer");
  }
  return upToDateOr(await repo.wirdTemplates(ctx), sinceVersion);
}
