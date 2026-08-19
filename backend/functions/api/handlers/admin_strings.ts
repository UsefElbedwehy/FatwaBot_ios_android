// Admin CRUD for config.string_packs (ADR-0011: UI copy is server-owned so text
// can change without an app release — e.g. the Tasbeeh screen's
// `tasbeeh.notice`, added by migration 0024).
//
// Version semantics live in ../admin_strings_types.ts; the short version is
// that "saving" always inserts a NEW version and publishing never unpublishes
// anything, because clients delta-sync on the highest published version.
import { apiError, json } from "../http.ts";
import type { AppContext } from "../types.ts";
import type { AuditLogRepo } from "../admin_types.ts";
import type { AdminStringsRepo, StringPackVersion } from "../admin_strings_types.ts";

/** Audit `collection` for every string-pack mutation. */
const AUDIT_COLLECTION = "string-packs";

// Guardrails, not product limits: a real pack is a few hundred short keys.
// These exist so a malformed paste can't write a multi-megabyte jsonb blob that
// every client then has to download on next sync.
const MAX_KEYS = 2000;
const MAX_KEY_LEN = 512;
const MAX_VALUE_LEN = 4000;

/** rowId for the audit log — config.string_packs has no uuid id, its identity
 * is (app_id, locale, version). */
function auditRowId(locale: string, version: number): string {
  return `${locale}:${version}`;
}

function serialize(pack: StringPackVersion): Record<string, unknown> {
  return {
    locale: pack.locale,
    version: pack.version,
    published: pack.published,
    strings: pack.strings,
  };
}

/** Validates the operator-authored map. No forbidden-key filtering here (unlike
 * analytics params): this is UI copy written by an admin, not user input. The
 * one hard requirement is that every value is a string — the apps decode the
 * pack as [String: String], so a number or nested object would fail to decode
 * on device and take the whole pack down with it. */
function validateStrings(raw: unknown): Record<string, string> | Response {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    return apiError(400, "invalid_strings", "strings must be a flat JSON object of key → string");
  }
  const entries = Object.entries(raw as Record<string, unknown>);
  if (entries.length > MAX_KEYS) {
    return apiError(400, "invalid_strings", `strings must contain at most ${MAX_KEYS} keys`);
  }
  const out: Record<string, string> = {};
  for (const [key, value] of entries) {
    if (key.length === 0 || key.length > MAX_KEY_LEN) {
      return apiError(400, "invalid_strings", `key must be 1–${MAX_KEY_LEN} characters: "${key}"`);
    }
    if (typeof value !== "string") {
      return apiError(
        400,
        "invalid_strings",
        `value for "${key}" must be a string (clients decode a flat string map)`,
      );
    }
    if (value.length > MAX_VALUE_LEN) {
      return apiError(400, "invalid_strings", `value for "${key}" exceeds ${MAX_VALUE_LEN} characters`);
    }
    out[key] = value;
  }
  return out;
}

/** GET /admin/v1/string-packs */
export async function handleListStringPacks(
  ctx: AppContext,
  repo: AdminStringsRepo,
): Promise<Response> {
  const summaries = await repo.listLocales(ctx);
  return json({
    locales: summaries.map((s) => ({
      locale: s.locale,
      published_version: s.publishedVersion,
      draft_version: s.draftVersion,
      key_count: s.keyCount,
    })),
  });
}

/** GET /admin/v1/string-packs/{locale}?version=N */
export async function handleGetStringPack(
  ctx: AppContext,
  repo: AdminStringsRepo,
  locale: string,
  versionParam: string | null,
): Promise<Response> {
  let version: number | null = null;
  if (versionParam !== null) {
    version = Number(versionParam);
    if (!Number.isInteger(version) || version < 1) {
      return apiError(400, "invalid_version", "version must be a positive integer");
    }
  }
  const pack = await repo.getPack(ctx, locale, version);
  if (!pack) {
    return apiError(404, "no_pack", `No string pack for locale ${locale}${version ? ` v${version}` : ""}`);
  }
  return json(serialize(pack));
}

/** POST /admin/v1/string-packs/{locale} — creates the next version. */
export async function handleCreateStringPackVersion(
  ctx: AppContext,
  repo: AdminStringsRepo,
  audit: AuditLogRepo,
  adminId: string,
  locale: string,
  body: unknown,
): Promise<Response> {
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return apiError(400, "invalid_body", "Request body must be a JSON object");
  }
  const b = body as { strings?: unknown; published?: unknown };
  if (b.published !== undefined && typeof b.published !== "boolean") {
    return apiError(400, "invalid_body", "published must be a boolean");
  }
  const strings = validateStrings(b.strings);
  if (strings instanceof Response) return strings;

  const published = b.published === true;
  const pack = await repo.createVersion(ctx, locale, strings, published);
  await audit.record(ctx, {
    adminId,
    collection: AUDIT_COLLECTION,
    rowId: auditRowId(pack.locale, pack.version),
    // AdminAction is constrained by a DB CHECK to create/update/publish/
    // unpublish, so a published insert is recorded as "publish" and a draft
    // insert as "create". There is no separate "new version" action.
    action: published ? "publish" : "create",
    before: null,
    after: serialize(pack),
  });
  return json(serialize(pack), 201);
}

/** PATCH /admin/v1/string-packs/{locale}/{version} — flips `published`. */
export async function handleSetStringPackPublished(
  ctx: AppContext,
  repo: AdminStringsRepo,
  audit: AuditLogRepo,
  adminId: string,
  locale: string,
  version: number,
  body: unknown,
): Promise<Response> {
  if (
    typeof body !== "object" || body === null ||
    typeof (body as { published?: unknown }).published !== "boolean"
  ) {
    return apiError(400, "invalid_body", "published must be a boolean");
  }
  const published = (body as { published: boolean }).published;
  const before = await repo.getPack(ctx, locale, version);
  if (!before) return apiError(404, "no_pack", `No string pack ${locale} v${version}`);

  const pack = await repo.setPublished(ctx, locale, version, published);
  if (!pack) return apiError(404, "no_pack", `No string pack ${locale} v${version}`);
  await audit.record(ctx, {
    adminId,
    collection: AUDIT_COLLECTION,
    rowId: auditRowId(locale, version),
    action: published ? "publish" : "unpublish",
    // `strings` is intentionally omitted: only the flag changed, and copying the
    // whole map into both sides of the audit row would bury the actual diff.
    before: { locale, version, published: before.published },
    after: { locale, version, published: pack.published },
  });
  return json(serialize(pack));
}
