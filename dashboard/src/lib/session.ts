// Admin session cookie (ADR-0009: never store the token in client-readable storage).
import { cookies } from "next/headers";
import { ADMIN_SESSION_COOKIE as COOKIE_NAME } from "./session-constants";

export async function getAdminToken(): Promise<string | null> {
  const store = await cookies();
  return store.get(COOKIE_NAME)?.value ?? null;
}

export async function setAdminSession(token: string, expiresInSeconds: number): Promise<void> {
  const store = await cookies();
  store.set(COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: expiresInSeconds,
  });
}

export async function clearAdminSession(): Promise<void> {
  const store = await cookies();
  store.delete(COOKIE_NAME);
}
