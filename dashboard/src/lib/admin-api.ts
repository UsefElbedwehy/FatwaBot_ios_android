// Admin API client (ADR-0009: dashboard talks only to /admin/v1 on the backend).
import { redirect } from "next/navigation";
import { clearAdminSession, getAdminToken } from "./session";

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL ?? "";

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
  createdAtEpochSeconds: number;
}

export interface LocaleInfo {
  locale: string;
  display_name: string;
  direction: "ltr" | "rtl";
}

/** One row of GET /admin/v1/string-packs, camelCased at the boundary like
 * AdminUser. `publishedVersion` is the version clients actually receive (the max
 * published one); `draftVersion` is the highest unpublished version, if any. */
export interface StringPackSummary {
  locale: string;
  publishedVersion: number | null;
  draftVersion: number | null;
  keyCount: number;
}

export interface StringPack {
  locale: string;
  version: number;
  published: boolean;
  strings: Record<string, string>;
}

export interface AdminUser {
  id: string;
  kind: "anonymous" | "account";
  provider: "anonymous" | "apple" | "google";
  displayName: string | null;
  countryCode: string | null;
  createdAtEpochSeconds: number;
  linkedAtEpochSeconds: number | null;
}

/** One ranked row of GET /admin/v1/leaderboards/{key}/standings — the full
 * board, unfiltered by region, so an admin can find any period's winner. */
export interface LeaderboardStandingEntry {
  rank: number;
  score: number;
  /** Empty for a global board; a country code or city name otherwise. */
  bucket: string;
  country: string | null;
  city: string | null;
  displayName: string;
}

export interface LeaderboardStandings {
  key: string;
  period: string;
  periodKey: string;
  isCurrentPeriod: boolean;
  entries: LeaderboardStandingEntry[];
}

const FALLBACK_LOCALES: LocaleInfo[] = [
  { locale: "ar", display_name: "العربية", direction: "rtl" },
  { locale: "en", display_name: "English", direction: "ltr" },
];

export class AdminApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

async function errorMessage(res: Response, fallback: string): Promise<string> {
  const body = await res.json().catch(() => null);
  return body?.error?.message ?? fallback;
}

/** Authenticated fetch against /admin/v1/*. Clears the session and redirects to
 * /login on a 401 so callers never need to special-case an expired token. */
async function adminFetch(path: string, init?: RequestInit): Promise<Response> {
  if (!API_BASE) throw new AdminApiError(0, "Backend not configured (NEXT_PUBLIC_API_BASE_URL unset)");
  const token = await getAdminToken();
  if (!token) redirect("/login");

  const res = await fetch(`${API_BASE}${path}`, {
    ...init,
    cache: "no-store",
    headers: {
      authorization: `Bearer ${token}`,
      ...(init?.body ? { "content-type": "application/json" } : {}),
      ...init?.headers,
    },
  });
  if (res.status === 401) {
    await clearAdminSession();
    redirect("/login");
  }
  return res;
}

export async function adminLogin(
  email: string,
  password: string,
): Promise<{ admin_id: string; access_token: string; expires_in: number }> {
  if (!API_BASE) throw new AdminApiError(0, "Backend not configured (NEXT_PUBLIC_API_BASE_URL unset)");
  const res = await fetch(`${API_BASE}/admin/v1/auth/login`, {
    method: "POST",
    cache: "no-store",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) throw new AdminApiError(res.status, await errorMessage(res, "Login failed"));
  return await res.json();
}

export async function listContent(collection: string): Promise<AdminContentRow[]> {
  const res = await adminFetch(`/admin/v1/content/${collection}`);
  if (!res.ok) throw new AdminApiError(res.status, await errorMessage(res, `Failed to list ${collection}`));
  const body = await res.json();
  return body.rows;
}

export async function getContentRow(collection: string, id: string): Promise<AdminContentRow | null> {
  const rows = await listContent(collection);
  return rows.find((r) => r.id === id) ?? null;
}

export async function createContent(
  collection: string,
  fields: Record<string, unknown>,
): Promise<AdminContentRow> {
  const res = await adminFetch(`/admin/v1/content/${collection}`, {
    method: "POST",
    body: JSON.stringify(fields),
  });
  if (!res.ok) throw new AdminApiError(res.status, await errorMessage(res, "Failed to create row"));
  return await res.json();
}

export async function updateContent(
  collection: string,
  id: string,
  fields: Record<string, unknown>,
): Promise<AdminContentRow> {
  const res = await adminFetch(`/admin/v1/content/${collection}/${id}`, {
    method: "PATCH",
    body: JSON.stringify(fields),
  });
  if (!res.ok) throw new AdminApiError(res.status, await errorMessage(res, "Failed to save changes"));
  return await res.json();
}

export async function setContentPublished(
  collection: string,
  id: string,
  published: boolean,
): Promise<AdminContentRow> {
  const res = await adminFetch(`/admin/v1/content/${collection}/${id}/${published ? "publish" : "unpublish"}`, {
    method: "POST",
  });
  if (!res.ok) {
    throw new AdminApiError(res.status, await errorMessage(res, `Failed to ${published ? "publish" : "unpublish"}`));
  }
  return await res.json();
}

export async function listStringPackLocales(): Promise<StringPackSummary[]> {
  const res = await adminFetch("/admin/v1/string-packs");
  if (!res.ok) throw new AdminApiError(res.status, await errorMessage(res, "Failed to list string packs"));
  const body = await res.json();
  return (body.locales as { locale: string; published_version: number | null; draft_version: number | null; key_count: number }[])
    .map((l) => ({
      locale: l.locale,
      publishedVersion: l.published_version,
      draftVersion: l.draft_version,
      keyCount: l.key_count,
    }));
}

/** Highest version for the locale (draft if one sits above the published one),
 * or a specific `version`. Null when the locale has no pack at all — the editor
 * treats that as "create the first pack" rather than an error. */
export async function getStringPack(locale: string, version?: number): Promise<StringPack | null> {
  const qs = version !== undefined ? `?version=${version}` : "";
  const res = await adminFetch(`/admin/v1/string-packs/${encodeURIComponent(locale)}${qs}`);
  if (res.status === 404) return null;
  if (!res.ok) throw new AdminApiError(res.status, await errorMessage(res, "Failed to load string pack"));
  return await res.json();
}

/** Always creates a NEW version (max + 1) — string packs are never edited in
 * place, because clients delta-sync on the version number (ADR-0011). */
export async function createStringPackVersion(
  locale: string,
  strings: Record<string, string>,
  published: boolean,
): Promise<StringPack> {
  const res = await adminFetch(`/admin/v1/string-packs/${encodeURIComponent(locale)}`, {
    method: "POST",
    body: JSON.stringify({ strings, published }),
  });
  if (!res.ok) throw new AdminApiError(res.status, await errorMessage(res, "Failed to save string pack"));
  return await res.json();
}

export async function setStringPackPublished(
  locale: string,
  version: number,
  published: boolean,
): Promise<StringPack> {
  const res = await adminFetch(`/admin/v1/string-packs/${encodeURIComponent(locale)}/${version}`, {
    method: "PATCH",
    body: JSON.stringify({ published }),
  });
  if (!res.ok) {
    throw new AdminApiError(res.status, await errorMessage(res, `Failed to ${published ? "publish" : "unpublish"}`));
  }
  return await res.json();
}

export async function listAuditLog(collection?: string): Promise<AuditEntry[]> {
  const qs = collection ? `?collection=${encodeURIComponent(collection)}` : "";
  const res = await adminFetch(`/admin/v1/audit-log${qs}`);
  if (!res.ok) throw new AdminApiError(res.status, await errorMessage(res, "Failed to load audit log"));
  const body = await res.json();
  return body.entries;
}

export async function listAdminUsers(query?: string): Promise<AdminUser[]> {
  const qs = query ? `?query=${encodeURIComponent(query)}` : "";
  const res = await adminFetch(`/admin/v1/users${qs}`);
  if (!res.ok) throw new AdminApiError(res.status, await errorMessage(res, "Failed to list users"));
  const body = await res.json();
  return body.users;
}

/** Full standings for one board. Omit `periodKey` for the current period —
 * the same window a user's own app would show — or pass one from
 * `listLeaderboardPeriods` to see a past period's final ranks (e.g. last
 * half's winner, after the board has already rolled to the next one). */
export async function listLeaderboardStandings(
  key: string,
  periodKey?: string,
): Promise<LeaderboardStandings> {
  const qs = periodKey ? `?period_key=${encodeURIComponent(periodKey)}` : "";
  const res = await adminFetch(`/admin/v1/leaderboards/${encodeURIComponent(key)}/standings${qs}`);
  if (!res.ok) throw new AdminApiError(res.status, await errorMessage(res, "Failed to load standings"));
  const body = await res.json();
  return {
    key: body.key,
    period: body.period,
    periodKey: body.period_key,
    isCurrentPeriod: body.is_current_period,
    entries: (body.entries as Record<string, unknown>[]).map((e) => ({
      rank: e.rank as number,
      score: e.score as number,
      bucket: e.bucket as string,
      country: e.country as string | null,
      city: e.city as string | null,
      displayName: e.display_name as string,
    })),
  };
}

/** Every period this board has ever had standings materialized for, newest
 * first — powers the "view a past period" picker on the standings page. */
export async function listLeaderboardPeriods(key: string): Promise<string[]> {
  const res = await adminFetch(`/admin/v1/leaderboards/${encodeURIComponent(key)}/periods`);
  if (!res.ok) throw new AdminApiError(res.status, await errorMessage(res, "Failed to load periods"));
  const body = await res.json();
  return body.periods;
}

/** Enabled locales drive the editor's locale tabs (spec: "tabs for enabled
 * locales from config.locales"). Public endpoint — no admin token needed. */
export async function getLocales(): Promise<LocaleInfo[]> {
  if (!API_BASE) return FALLBACK_LOCALES;
  try {
    const res = await fetch(`${API_BASE}/v1/config`, { cache: "no-store" });
    if (!res.ok) return FALLBACK_LOCALES;
    const body = await res.json();
    return Array.isArray(body.locales) && body.locales.length > 0 ? body.locales : FALLBACK_LOCALES;
  } catch {
    return FALLBACK_LOCALES;
  }
}
