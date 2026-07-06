// Account linking & profile (docs/features/accounts.md, M3). Extends the
// anonymous-first auth from M1 with Apple/Google sign-in and anonymous ->
// account linking that preserves user_id.
import { verifyAccessToken } from "../auth/jwt.ts";
import type { IdentityProviderVerifier, ProviderKind } from "../auth/provider_verify.ts";
import { apiError, json } from "../http.ts";
import type { AppContext } from "../types.ts";
import { type AuthDeps, isValidDevice, tokenResponse } from "./auth.ts";

interface AccountDeps extends AuthDeps {
  verifier: IdentityProviderVerifier;
}

function bearerClaims(req: Request, jwtSecret: string) {
  const header = req.headers.get("authorization");
  if (!header?.startsWith("Bearer ")) return null;
  return verifyAccessToken(header.slice("Bearer ".length), jwtSecret);
}

function isValidIdentityToken(body: unknown): body is { identity_token: string } {
  if (typeof body !== "object" || body === null) return false;
  const token = (body as Record<string, unknown>).identity_token;
  return typeof token === "string" && token.length > 0;
}

/** POST /v1/auth/apple | /v1/auth/google — sign in (or reuse) an account by provider identity. */
export async function handleProviderSignIn(
  ctx: AppContext,
  deps: AccountDeps,
  provider: ProviderKind,
  body: unknown,
): Promise<Response> {
  if (!isValidIdentityToken(body)) {
    return apiError(400, "invalid_body", "identity_token is required");
  }
  if (!isValidDevice(body)) {
    return apiError(
      400,
      "invalid_device",
      "Body must include device {platform, app_version, locale, timezone}",
    );
  }
  const verified = await deps.verifier.verify(provider, body.identity_token);
  if (!verified) return apiError(401, "invalid_identity_token", "Could not verify provider identity token");

  const { userId, deviceId } = await deps.identity.findOrCreateProviderUser(
    ctx,
    provider,
    verified.subject,
    body.device,
  );
  return await tokenResponse(deps, ctx, userId, deviceId, "account");
}

/** POST /v1/auth/link — upgrade the authenticated (typically anonymous) user in place. */
export async function handleLinkProvider(
  ctx: AppContext,
  deps: AccountDeps,
  req: Request,
  body: unknown,
): Promise<Response> {
  const claims = await bearerClaims(req, deps.jwtSecret);
  if (!claims) return apiError(401, "unauthorized", "Valid bearer token required");

  if (typeof body !== "object" || body === null) {
    return apiError(400, "invalid_body", "provider and identity_token are required");
  }
  const b = body as Record<string, unknown>;
  if (b.provider !== "apple" && b.provider !== "google") {
    return apiError(400, "invalid_provider", "provider must be 'apple' or 'google'");
  }
  if (!isValidIdentityToken(body)) {
    return apiError(400, "invalid_body", "identity_token is required");
  }

  const verified = await deps.verifier.verify(b.provider, body.identity_token);
  if (!verified) return apiError(401, "invalid_identity_token", "Could not verify provider identity token");

  const result = await deps.identity.linkProvider(ctx, claims.sub, b.provider, verified.subject);
  if (result === "already_linked_elsewhere") {
    return apiError(409, "already_linked", "This provider identity is already linked to a different account");
  }
  return json({ user_id: claims.sub, provider: b.provider, linked: true });
}

/** PATCH /v1/me/profile — set or clear the optional, self-chosen display name. */
export async function handleUpdateProfile(deps: AccountDeps, req: Request, body: unknown): Promise<Response> {
  const claims = await bearerClaims(req, deps.jwtSecret);
  if (!claims) return apiError(401, "unauthorized", "Valid bearer token required");

  if (typeof body !== "object" || body === null || !("display_name" in (body as Record<string, unknown>))) {
    return apiError(400, "invalid_body", "display_name is required (use null to clear)");
  }
  const displayName = (body as Record<string, unknown>).display_name;
  if (
    displayName !== null &&
    (typeof displayName !== "string" || displayName.length === 0 || displayName.length > 50)
  ) {
    return apiError(400, "invalid_display_name", "display_name must be 1-50 characters, or null to clear");
  }
  await deps.identity.updateDisplayName(claims.sub, displayName);
  return json({ user_id: claims.sub, display_name: displayName });
}
