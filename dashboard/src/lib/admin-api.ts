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

export async function listAuditLog(collection?: string): Promise<AuditEntry[]> {
  const qs = collection ? `?collection=${encodeURIComponent(collection)}` : "";
  const res = await adminFetch(`/admin/v1/audit-log${qs}`);
  if (!res.ok) throw new AdminApiError(res.status, await errorMessage(res, "Failed to load audit log"));
  const body = await res.json();
  return body.entries;
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
