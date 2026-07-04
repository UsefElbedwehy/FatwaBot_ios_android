import type { AppContext } from "./types.ts";

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
}
