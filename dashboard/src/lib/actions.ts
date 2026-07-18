"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import {
  AdminApiError,
  adminLogin,
  createContent,
  getLocales,
  setContentPublished,
  updateContent,
} from "./admin-api";
import { clearAdminSession, setAdminSession } from "./session";
import { getCollectionDef } from "./collections";

export interface FormState {
  error?: string;
  success?: boolean;
}

async function parseFieldsFromForm(collection: string, formData: FormData): Promise<Record<string, unknown>> {
  const def = getCollectionDef(collection);
  if (!def) throw new Error(`Unknown collection: ${collection}`);
  const locales = await getLocales();
  const fields: Record<string, unknown> = {};

  for (const field of def.fields) {
    if (field.kind === "translatable" || field.kind === "translatable-textarea") {
      const map: Record<string, string> = {};
      for (const loc of locales) {
        const value = formData.get(`${field.key}.${loc.locale}`);
        if (typeof value === "string" && value.trim().length > 0) map[loc.locale] = value;
      }
      fields[field.key] = map;
    } else if (field.kind === "number") {
      const raw = formData.get(field.key);
      fields[field.key] = raw !== null && raw !== "" ? Number(raw) : 0;
    } else if (field.kind === "boolean") {
      fields[field.key] = formData.get(field.key) === "on";
    } else if (field.kind === "array") {
      const raw = String(formData.get(field.key) ?? "");
      fields[field.key] = raw
        .split("\n")
        .map((v) => v.trim())
        .filter((v) => v.length > 0);
    } else if (field.kind === "json") {
      const raw = String(formData.get(field.key) ?? "").trim();
      if (raw.length === 0) {
        fields[field.key] = {};
      } else {
        try {
          fields[field.key] = JSON.parse(raw);
        } catch {
          throw new Error(`${field.label}: invalid JSON`);
        }
      }
    } else if (field.kind === "optional-text") {
      // Nullable columns (e.g. timestamptz start/end dates) must submit null
      // when empty, not "" — an empty string fails to cast on the backend.
      const raw = formData.get(field.key);
      fields[field.key] = raw === null || raw === "" ? null : String(raw);
    } else {
      fields[field.key] = String(formData.get(field.key) ?? "");
    }
  }
  return fields;
}

export async function loginAction(_prev: FormState, formData: FormData): Promise<FormState> {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  const next = String(formData.get("next") ?? "/content");
  if (!email || !password) return { error: "Email and password are required" };

  try {
    const result = await adminLogin(email, password);
    await setAdminSession(result.access_token, result.expires_in);
  } catch (err) {
    if (err instanceof AdminApiError) return { error: err.message };
    throw err;
  }
  redirect(next.startsWith("/") ? next : "/content");
}

export async function logoutAction(): Promise<void> {
  await clearAdminSession();
  redirect("/login");
}

export async function createContentAction(
  collection: string,
  _prev: FormState,
  formData: FormData,
): Promise<FormState> {
  try {
    const fields = await parseFieldsFromForm(collection, formData);
    const row = await createContent(collection, fields);
    revalidatePath(`/content/${collection}`);
    redirect(`/content/${collection}/${row.id}`);
  } catch (err) {
    if (err instanceof AdminApiError) return { error: err.message };
    throw err;
  }
}

export async function updateContentAction(
  collection: string,
  id: string,
  _prev: FormState,
  formData: FormData,
): Promise<FormState> {
  try {
    const fields = await parseFieldsFromForm(collection, formData);
    await updateContent(collection, id, fields);
    revalidatePath(`/content/${collection}`);
    revalidatePath(`/content/${collection}/${id}`);
    return { success: true };
  } catch (err) {
    if (err instanceof AdminApiError) return { error: err.message };
    throw err;
  }
}

export async function setPublishedAction(collection: string, id: string, published: boolean): Promise<void> {
  await setContentPublished(collection, id, published);
  revalidatePath(`/content/${collection}`);
  revalidatePath(`/content/${collection}/${id}`);
}
