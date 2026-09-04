import { assertEquals } from "jsr:@std/assert@1";
import { createLocalJWKSet, exportJWK, generateKeyPair, type KeyLike, SignJWT } from "npm:jose@5";
import {
  APPLE_ISSUER,
  AppleIdentityVerifier,
  DevIdentityProviderVerifier,
  GoogleIdentityVerifier,
  RemoteIdentityProviderVerifier,
  verifierFromEnv,
} from "../functions/api/auth/provider_verify.ts";

const APPLE_AUD = "com.fatwabot.app";
const GOOGLE_AUDS = ["web-client.apps.googleusercontent.com", "ios-client.apps.googleusercontent.com"];

/** A local signing key + matching JWKS, standing in for the provider's keys. */
async function keyFixture() {
  const { privateKey, publicKey } = await generateKeyPair("RS256", { extractable: true });
  const jwk = await exportJWK(publicKey);
  jwk.kid = "test-key";
  jwk.alg = "RS256";
  return { privateKey, keys: createLocalJWKSet({ keys: [jwk] }) };
}

function token(privateKey: KeyLike, claims: Record<string, unknown>, opts: {
  issuer: string;
  audience: string;
  expiresIn?: string;
}) {
  return new SignJWT(claims)
    .setProtectedHeader({ alg: "RS256", kid: "test-key" })
    .setIssuer(opts.issuer)
    .setAudience(opts.audience)
    .setIssuedAt()
    .setExpirationTime(opts.expiresIn ?? "1h")
    .sign(privateKey);
}

Deno.test("Apple: accepts a correctly signed token and returns sub", async () => {
  const { privateKey, keys } = await keyFixture();
  const jwt = await token(privateKey, { sub: "apple-user-1" }, { issuer: APPLE_ISSUER, audience: APPLE_AUD });
  const result = await new AppleIdentityVerifier(APPLE_AUD, keys).verify(jwt);
  assertEquals(result, { subject: "apple-user-1" });
});

Deno.test("Apple: rejects a token for a different audience (another app)", async () => {
  const { privateKey, keys } = await keyFixture();
  const jwt = await token(privateKey, { sub: "x" }, { issuer: APPLE_ISSUER, audience: "com.someone.else" });
  assertEquals(await new AppleIdentityVerifier(APPLE_AUD, keys).verify(jwt), null);
});

Deno.test("Apple: rejects a wrong issuer", async () => {
  const { privateKey, keys } = await keyFixture();
  const jwt = await token(privateKey, { sub: "x" }, { issuer: "https://evil.example", audience: APPLE_AUD });
  assertEquals(await new AppleIdentityVerifier(APPLE_AUD, keys).verify(jwt), null);
});

Deno.test("Apple: rejects an expired token", async () => {
  const { privateKey, keys } = await keyFixture();
  const jwt = await token(privateKey, { sub: "x" }, {
    issuer: APPLE_ISSUER,
    audience: APPLE_AUD,
    expiresIn: "-1m",
  });
  assertEquals(await new AppleIdentityVerifier(APPLE_AUD, keys).verify(jwt), null);
});

Deno.test("Apple: rejects a token signed by a foreign key (forgery)", async () => {
  const attacker = await keyFixture();
  const real = await keyFixture();
  const jwt = await token(attacker.privateKey, { sub: "x" }, { issuer: APPLE_ISSUER, audience: APPLE_AUD });
  // Verified against the *real* JWKS → signature fails.
  assertEquals(await new AppleIdentityVerifier(APPLE_AUD, real.keys).verify(jwt), null);
});

Deno.test("Apple: rejects garbage", async () => {
  const { keys } = await keyFixture();
  const verifier = new AppleIdentityVerifier(APPLE_AUD, keys);
  assertEquals(await verifier.verify("not-a-jwt"), null);
  assertEquals(await verifier.verify(""), null);
});

Deno.test("Google: accepts either configured client id", async () => {
  const { privateKey, keys } = await keyFixture();
  const verifier = new GoogleIdentityVerifier(GOOGLE_AUDS, keys);
  for (const aud of GOOGLE_AUDS) {
    const jwt = await token(privateKey, { sub: "g-1" }, {
      issuer: "https://accounts.google.com",
      audience: aud,
    });
    assertEquals(await verifier.verify(jwt), { subject: "g-1" });
  }
});

Deno.test("Google: accepts the bare issuer spelling", async () => {
  const { privateKey, keys } = await keyFixture();
  const jwt = await token(privateKey, { sub: "g-2" }, {
    issuer: "accounts.google.com",
    audience: GOOGLE_AUDS[0],
  });
  assertEquals(await new GoogleIdentityVerifier(GOOGLE_AUDS, keys).verify(jwt), { subject: "g-2" });
});

Deno.test("Google: rejects an unknown client id", async () => {
  const { privateKey, keys } = await keyFixture();
  const jwt = await token(privateKey, { sub: "g" }, {
    issuer: "https://accounts.google.com",
    audience: "attacker-client.apps.googleusercontent.com",
  });
  assertEquals(await new GoogleIdentityVerifier(GOOGLE_AUDS, keys).verify(jwt), null);
});

Deno.test("Google: rejects an explicitly unverified email", async () => {
  const { privateKey, keys } = await keyFixture();
  const jwt = await token(privateKey, { sub: "g", email_verified: false }, {
    issuer: "https://accounts.google.com",
    audience: GOOGLE_AUDS[0],
  });
  assertEquals(await new GoogleIdentityVerifier(GOOGLE_AUDS, keys).verify(jwt), null);
});

Deno.test("Router verifier dispatches per provider", async () => {
  const { privateKey, keys } = await keyFixture();
  const verifier = new RemoteIdentityProviderVerifier(
    new AppleIdentityVerifier(APPLE_AUD, keys),
    new GoogleIdentityVerifier(GOOGLE_AUDS, keys),
  );
  const appleJwt = await token(privateKey, { sub: "a" }, { issuer: APPLE_ISSUER, audience: APPLE_AUD });
  assertEquals(await verifier.verify("apple", appleJwt), { subject: "a" });
  // An Apple token must not be accepted as a Google one.
  assertEquals(await verifier.verify("google", appleJwt), null);
  assertEquals(await verifier.verify("apple", ""), null);
});

Deno.test("verifierFromEnv honours the dev escape hatch, else builds the real verifier", () => {
  const dev = verifierFromEnv((k) => (k === "AUTH_VERIFIER" ? "dev" : undefined));
  assertEquals(dev instanceof DevIdentityProviderVerifier, true);
  const real = verifierFromEnv(() => undefined);
  assertEquals(real instanceof RemoteIdentityProviderVerifier, true);
});
