// Stateless access tokens (HS256 via jose). Claims: sub (user id), app_id, kind.
// Clients treat these as opaque (ADR-0004); the signing scheme can change server-side.
import { jwtVerify, SignJWT } from "npm:jose@5";

export interface AccessClaims {
  sub: string;
  app_id: string;
  kind: "anonymous" | "account";
}

const ISSUER = "fatwabot-api";
export const ACCESS_TTL_SECONDS = 60 * 60; // 1h
export const REFRESH_TTL_SECONDS = 60 * 60 * 24 * 90; // 90d

function key(secret: string): Uint8Array {
  return new TextEncoder().encode(secret);
}

export async function signAccessToken(claims: AccessClaims, secret: string): Promise<string> {
  return await new SignJWT({ app_id: claims.app_id, kind: claims.kind })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(claims.sub)
    .setIssuer(ISSUER)
    .setIssuedAt()
    .setExpirationTime(`${ACCESS_TTL_SECONDS}s`)
    .sign(key(secret));
}

export async function verifyAccessToken(token: string, secret: string): Promise<AccessClaims | null> {
  try {
    const { payload } = await jwtVerify(token, key(secret), { issuer: ISSUER });
    if (typeof payload.sub !== "string" || typeof payload.app_id !== "string") return null;
    return {
      sub: payload.sub,
      app_id: payload.app_id as string,
      kind: (payload.kind as AccessClaims["kind"]) ?? "anonymous",
    };
  } catch {
    return null;
  }
}

/** Opaque refresh token + its storage hash (sha-256 hex). */
export async function mintRefreshToken(): Promise<{ token: string; hash: string }> {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  const token = btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
  return { token, hash: await hashRefreshToken(token) };
}

export async function hashRefreshToken(token: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
