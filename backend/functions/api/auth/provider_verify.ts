// Provider identity verification (docs/features/accounts.md). Pluggable
// interface so the dev stub and the real Apple/Google verifiers share one
// contract behind /v1/auth/apple|google|link.

import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from "npm:jose@5";

export type ProviderKind = "apple" | "google";

export interface IdentityProviderVerifier {
  verify(provider: ProviderKind, identityToken: string): Promise<{ subject: string } | null>;
}

/** Dev-mode stub: treats the presented identity_token as already being the
 * stable provider subject id. Deterministic and safe for tests/local dev;
 * NOT suitable for production — a real verifier must check the token's
 * signature against the provider's published keys before trusting it. */
export class DevIdentityProviderVerifier implements IdentityProviderVerifier {
  verify(_provider: ProviderKind, identityToken: string): Promise<{ subject: string } | null> {
    if (typeof identityToken !== "string" || identityToken.length < 4) return Promise.resolve(null);
    return Promise.resolve({ subject: identityToken });
  }
}

// --- Real verification -------------------------------------------------------
// Both providers issue OIDC ID tokens (RS256) signed with rotating keys
// published as a JWKS. We verify signature + issuer + audience + expiry, then
// trust `sub` as the stable provider subject id. Anything that fails any check
// returns null → the handler answers 401 rather than minting an account.

export const APPLE_ISSUER = "https://appleid.apple.com";
export const APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys";
/** Google mints ID tokens with either issuer spelling. */
export const GOOGLE_ISSUERS = ["https://accounts.google.com", "accounts.google.com"];
export const GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs";

/** The app's public client identifiers. These ship inside the mobile binaries,
 * so they are not secrets; env vars allow overriding per deployment. */
export const DEFAULT_APPLE_AUDIENCE = "com.fatwabot.app";
export const DEFAULT_GOOGLE_AUDIENCES = [
  // Web/server client — the audience when Android signs in with serverClientId.
  "665767164439-kgoe4prr2dsiv9ih9h02250cm4p5kbtb.apps.googleusercontent.com",
  // iOS client — the audience when the iOS GoogleSignIn SDK issues the token.
  "665767164439-gbe98ql9lddnddflkmev7vaira6mako3.apps.googleusercontent.com",
];

/** Verifies Apple ID tokens. `audience` is the app's bundle id. */
export class AppleIdentityVerifier {
  private readonly keys: JWTVerifyGetKey;

  constructor(private readonly audience: string, keys?: JWTVerifyGetKey) {
    this.keys = keys ?? createRemoteJWKSet(new URL(APPLE_JWKS_URL));
  }

  async verify(identityToken: string): Promise<{ subject: string } | null> {
    try {
      const { payload } = await jwtVerify(identityToken, this.keys, {
        issuer: APPLE_ISSUER,
        audience: this.audience,
      });
      return typeof payload.sub === "string" && payload.sub.length > 0 ? { subject: payload.sub } : null;
    } catch {
      return null;
    }
  }
}

/** Verifies Google ID tokens against any of the app's OAuth client ids. */
export class GoogleIdentityVerifier {
  private readonly keys: JWTVerifyGetKey;

  constructor(private readonly audiences: string[], keys?: JWTVerifyGetKey) {
    this.keys = keys ?? createRemoteJWKSet(new URL(GOOGLE_JWKS_URL));
  }

  async verify(identityToken: string): Promise<{ subject: string } | null> {
    try {
      const { payload } = await jwtVerify(identityToken, this.keys, {
        issuer: GOOGLE_ISSUERS,
        audience: this.audiences,
      });
      // Google-specific: reject unverified emails' tokens only if the claim is
      // present and explicitly false (the claim is absent for some flows).
      if (payload.email_verified === false) return null;
      return typeof payload.sub === "string" && payload.sub.length > 0 ? { subject: payload.sub } : null;
    } catch {
      return null;
    }
  }
}

/** Routes each provider to its real verifier. */
export class RemoteIdentityProviderVerifier implements IdentityProviderVerifier {
  constructor(
    private readonly apple: AppleIdentityVerifier,
    private readonly google: GoogleIdentityVerifier,
  ) {}

  verify(provider: ProviderKind, identityToken: string): Promise<{ subject: string } | null> {
    if (typeof identityToken !== "string" || identityToken.length === 0) return Promise.resolve(null);
    return provider === "apple" ? this.apple.verify(identityToken) : this.google.verify(identityToken);
  }
}

/** Builds the production verifier from env (falling back to the app's public
 * client ids). Set `AUTH_VERIFIER=dev` to keep the stub for a staging project. */
export function verifierFromEnv(env: (key: string) => string | undefined): IdentityProviderVerifier {
  if (env("AUTH_VERIFIER") === "dev") return new DevIdentityProviderVerifier();
  const appleAudience = env("APPLE_BUNDLE_ID") ?? DEFAULT_APPLE_AUDIENCE;
  const googleAudiences = env("GOOGLE_CLIENT_IDS")?.split(",").map((s) => s.trim()).filter(Boolean) ??
    DEFAULT_GOOGLE_AUDIENCES;
  return new RemoteIdentityProviderVerifier(
    new AppleIdentityVerifier(appleAudience),
    new GoogleIdentityVerifier(googleAudiences),
  );
}
