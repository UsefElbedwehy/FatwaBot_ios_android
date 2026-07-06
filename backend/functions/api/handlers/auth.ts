import {
  ACCESS_TTL_SECONDS,
  hashRefreshToken,
  mintRefreshToken,
  REFRESH_TTL_SECONDS,
  signAccessToken,
} from "../auth/jwt.ts";
import { apiError, json } from "../http.ts";
import type { AppContext } from "../types.ts";
import type { DeviceRegistration, IdentityRepo } from "../identity_types.ts";

export interface AuthDeps {
  identity: IdentityRepo;
  jwtSecret: string;
}

export function isValidDevice(body: unknown): body is { device: DeviceRegistration } {
  if (typeof body !== "object" || body === null) return false;
  const device = (body as Record<string, unknown>).device;
  if (typeof device !== "object" || device === null) return false;
  const d = device as Record<string, unknown>;
  return (d.platform === "ios" || d.platform === "android") &&
    typeof d.app_version === "string" && d.app_version.length > 0 &&
    typeof d.locale === "string" &&
    typeof d.timezone === "string";
}

export async function tokenResponse(
  deps: AuthDeps,
  ctx: AppContext,
  userId: string,
  deviceId: string,
  kind: "anonymous" | "account",
  rotatedFrom?: string,
): Promise<Response> {
  const accessToken = await signAccessToken({ sub: userId, app_id: ctx.appId, kind }, deps.jwtSecret);
  const refresh = await mintRefreshToken();
  const expiresAt = new Date(Date.now() + REFRESH_TTL_SECONDS * 1000);
  await deps.identity.storeRefreshToken(refresh.hash, userId, deviceId, expiresAt, rotatedFrom);
  return json({
    user_id: userId,
    kind,
    access_token: accessToken,
    expires_in: ACCESS_TTL_SECONDS,
    refresh_token: refresh.token,
  });
}

/** POST /v1/auth/anonymous — zero-signup identity (ADR-0004). */
export async function handleAnonymousAuth(ctx: AppContext, deps: AuthDeps, body: unknown): Promise<Response> {
  if (!isValidDevice(body)) {
    return apiError(
      400,
      "invalid_device",
      "Body must include device {platform, app_version, locale, timezone}",
    );
  }
  const { userId, deviceId } = await deps.identity.createAnonymousUser(ctx, body.device);
  return await tokenResponse(deps, ctx, userId, deviceId, "anonymous");
}

/** POST /v1/auth/refresh — single-use rotation; a used/revoked token is rejected. */
export async function handleRefresh(ctx: AppContext, deps: AuthDeps, body: unknown): Promise<Response> {
  const token = (body as Record<string, unknown> | null)?.refresh_token;
  if (typeof token !== "string" || token.length < 20) {
    return apiError(400, "invalid_refresh_token", "refresh_token required");
  }
  const record = await deps.identity.findRefreshToken(await hashRefreshToken(token));
  if (!record || record.revokedAt !== null || record.expiresAt.getTime() < Date.now()) {
    return apiError(401, "refresh_rejected", "Refresh token is invalid, expired, or already used");
  }
  const kind = (await deps.identity.userKind(record.userId)) ?? "anonymous";
  await deps.identity.revokeRefreshToken(record.id);
  return await tokenResponse(deps, ctx, record.userId, record.deviceId, kind, record.id);
}
