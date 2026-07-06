// Provider identity verification (docs/features/accounts.md). Pluggable
// interface so real Apple/Google token verification can drop in later
// without changing /v1/auth/apple|google|link's contract (Q8: credentials
// not available yet — mirrors ADR-0004's self-issued-now pattern).

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
