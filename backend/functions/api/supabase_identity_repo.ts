import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AppContext } from "./types.ts";
import type { DeviceRegistration, IdentityRepo, RefreshTokenRecord } from "./identity_types.ts";

export class SupabaseIdentityRepo implements IdentityRepo {
  constructor(private readonly db: SupabaseClient) {}

  async createAnonymousUser(
    ctx: AppContext,
    device: DeviceRegistration,
  ): Promise<{ userId: string; deviceId: string }> {
    const { data: user, error: userError } = await this.db
      .schema("identity").from("users")
      .insert({ app_id: ctx.appId, kind: "anonymous" })
      .select("id")
      .single();
    if (userError) throw userError;

    const { data: dev, error: deviceError } = await this.db
      .schema("identity").from("devices")
      .insert({
        user_id: user.id,
        platform: device.platform,
        locale: device.locale,
        timezone: device.timezone,
        app_version: device.app_version,
      })
      .select("id")
      .single();
    if (deviceError) throw deviceError;
    return { userId: user.id, deviceId: dev.id };
  }

  async userKind(userId: string): Promise<"anonymous" | "account" | null> {
    const { data, error } = await this.db
      .schema("identity").from("users")
      .select("kind")
      .eq("id", userId)
      .maybeSingle();
    if (error) throw error;
    return data?.kind ?? null;
  }

  async storeRefreshToken(
    hash: string,
    userId: string,
    deviceId: string,
    expiresAt: Date,
    rotatedFrom?: string,
  ): Promise<string> {
    const { data, error } = await this.db
      .schema("identity").from("refresh_tokens")
      .insert({
        token_hash: hash,
        user_id: userId,
        device_id: deviceId,
        expires_at: expiresAt.toISOString(),
        rotated_from: rotatedFrom ?? null,
      })
      .select("id")
      .single();
    if (error) throw error;
    return data.id;
  }

  async findRefreshToken(hash: string): Promise<RefreshTokenRecord | null> {
    const { data, error } = await this.db
      .schema("identity").from("refresh_tokens")
      .select("id,user_id,device_id,expires_at,revoked_at")
      .eq("token_hash", hash)
      .maybeSingle();
    if (error) throw error;
    if (!data) return null;
    return {
      id: data.id,
      userId: data.user_id,
      deviceId: data.device_id,
      expiresAt: new Date(data.expires_at),
      revokedAt: data.revoked_at ? new Date(data.revoked_at) : null,
    };
  }

  async revokeRefreshToken(id: string): Promise<void> {
    const { error } = await this.db
      .schema("identity").from("refresh_tokens")
      .update({ revoked_at: new Date().toISOString() })
      .eq("id", id);
    if (error) throw error;
  }
}
