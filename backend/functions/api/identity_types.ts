import type { AppContext } from "./types.ts";
import type { ProviderKind } from "./auth/provider_verify.ts";

export interface DeviceRegistration {
  platform: "ios" | "android";
  app_version: string;
  locale: string;
  timezone: string;
}

export interface RefreshTokenRecord {
  id: string;
  userId: string;
  deviceId: string;
  expiresAt: Date;
  revokedAt: Date | null;
}

export interface UserProfile {
  displayName: string | null;
  provider: "anonymous" | ProviderKind;
}

export type LinkProviderResult = "linked" | "already_linked_elsewhere";

/** Write-side repository for identity flows. Implemented by SupabaseIdentityRepo
 *  (production) and InMemoryIdentityRepo (tests). */
export interface IdentityRepo {
  createAnonymousUser(
    ctx: AppContext,
    device: DeviceRegistration,
  ): Promise<{ userId: string; deviceId: string }>;
  userKind(userId: string): Promise<"anonymous" | "account" | null>;
  storeRefreshToken(
    hash: string,
    userId: string,
    deviceId: string,
    expiresAt: Date,
    rotatedFrom?: string,
  ): Promise<string>;
  findRefreshToken(hash: string): Promise<RefreshTokenRecord | null>;
  revokeRefreshToken(id: string): Promise<void>;

  /** Sign-in via Apple/Google (docs/features/accounts.md): finds the existing
   * user for this provider identity, or creates a new account-kind user. */
  findOrCreateProviderUser(
    ctx: AppContext,
    provider: ProviderKind,
    providerSubject: string,
    device: DeviceRegistration,
  ): Promise<{ userId: string; deviceId: string }>;
  /** Upgrades an existing (typically anonymous) user in place — same user_id,
   * no data migration. Rejects if the provider identity already belongs to a
   * different account. */
  linkProvider(
    ctx: AppContext,
    userId: string,
    provider: ProviderKind,
    providerSubject: string,
  ): Promise<LinkProviderResult>;
  getProfile(userId: string): Promise<UserProfile | null>;
  updateDisplayName(userId: string, displayName: string | null): Promise<void>;
  /** Store the FCM push token on the user's device(s) — set null to clear. */
  updatePushToken(userId: string, token: string | null): Promise<void>;
  /** Every device with a registered push token — the push audience. */
  listPushTargets(ctx: AppContext): Promise<{ userId: string; token: string }[]>;
}
