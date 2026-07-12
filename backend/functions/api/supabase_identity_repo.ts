import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AppContext } from "./types.ts";
import type {
  DeviceRegistration,
  IdentityRepo,
  LinkProviderResult,
  RefreshTokenRecord,
  UserProfile,
} from "./identity_types.ts";
import type { ProviderKind } from "./auth/provider_verify.ts";

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

  async findOrCreateProviderUser(
    ctx: AppContext,
    provider: ProviderKind,
    providerSubject: string,
    device: DeviceRegistration,
  ): Promise<{ userId: string; deviceId: string }> {
    const { data: existing, error: findError } = await this.db
      .schema("identity").from("users")
      .select("id")
      .eq("app_id", ctx.appId).eq("provider", provider).eq("provider_subject", providerSubject)
      .maybeSingle();
    if (findError) throw findError;

    let userId: string;
    if (existing) {
      userId = existing.id;
    } else {
      const { data: created, error: createError } = await this.db
        .schema("identity").from("users")
        .insert({
          app_id: ctx.appId,
          kind: "account",
          provider,
          provider_subject: providerSubject,
          linked_at: new Date().toISOString(),
        })
        .select("id")
        .single();
      if (createError) throw createError;
      userId = created.id;
    }

    const { data: dev, error: deviceError } = await this.db
      .schema("identity").from("devices")
      .insert({
        user_id: userId,
        platform: device.platform,
        locale: device.locale,
        timezone: device.timezone,
        app_version: device.app_version,
      })
      .select("id")
      .single();
    if (deviceError) throw deviceError;
    return { userId, deviceId: dev.id };
  }

  async linkProvider(
    ctx: AppContext,
    userId: string,
    provider: ProviderKind,
    providerSubject: string,
  ): Promise<LinkProviderResult> {
    const { data: existing, error: findError } = await this.db
      .schema("identity").from("users")
      .select("id")
      .eq("app_id", ctx.appId).eq("provider", provider).eq("provider_subject", providerSubject)
      .maybeSingle();
    if (findError) throw findError;
    if (existing && existing.id !== userId) return "already_linked_elsewhere";

    const { error } = await this.db
      .schema("identity").from("users")
      .update({
        kind: "account",
        provider,
        provider_subject: providerSubject,
        linked_at: new Date().toISOString(),
      })
      .eq("id", userId);
    if (error) throw error;
    return "linked";
  }

  async getProfile(userId: string): Promise<UserProfile | null> {
    const { data, error } = await this.db
      .schema("identity").from("users")
      .select("display_name,provider")
      .eq("id", userId)
      .maybeSingle();
    if (error) throw error;
    return data ? { displayName: data.display_name, provider: data.provider } : null;
  }

  async updateDisplayName(userId: string, displayName: string | null): Promise<void> {
    const { error } = await this.db
      .schema("identity").from("users")
      .update({ display_name: displayName })
      .eq("id", userId);
    if (error) throw error;
  }

  async updatePushToken(userId: string, token: string | null): Promise<void> {
    // One device per anonymous install in practice; update the user's device(s).
    const { error } = await this.db
      .schema("identity").from("devices")
      .update({ push_token: token })
      .eq("user_id", userId);
    if (error) throw error;
  }
}
