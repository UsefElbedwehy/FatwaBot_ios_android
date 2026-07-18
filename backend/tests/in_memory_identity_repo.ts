import type { AppContext } from "../functions/api/types.ts";
import type {
  DeviceRegistration,
  IdentityRepo,
  LinkProviderResult,
  RefreshTokenRecord,
  UserProfile,
} from "../functions/api/identity_types.ts";
import type { ProviderKind } from "../functions/api/auth/provider_verify.ts";

interface UserRecord {
  kind: "anonymous" | "account";
  provider: "anonymous" | ProviderKind;
  providerSubject: string | null;
  displayName: string | null;
}

export class InMemoryIdentityRepo implements IdentityRepo {
  users = new Map<string, UserRecord>();
  devices = new Map<string, { userId: string; registration: DeviceRegistration; pushToken?: string | null }>();
  tokens = new Map<string, RefreshTokenRecord & { hash: string }>();
  private providerIndex = new Map<string, string>(); // `${provider}:${subject}` -> userId
  private counter = 0;

  private nextId(prefix: string): string {
    this.counter += 1;
    return `${prefix}-${this.counter.toString().padStart(4, "0")}`;
  }

  createAnonymousUser(_ctx: AppContext, device: DeviceRegistration) {
    const userId = this.nextId("user");
    const deviceId = this.nextId("device");
    this.users.set(userId, {
      kind: "anonymous",
      provider: "anonymous",
      providerSubject: null,
      displayName: null,
    });
    this.devices.set(deviceId, { userId, registration: device });
    return Promise.resolve({ userId, deviceId });
  }

  userKind(userId: string) {
    return Promise.resolve(this.users.get(userId)?.kind ?? null);
  }

  findOrCreateProviderUser(
    _ctx: AppContext,
    provider: ProviderKind,
    providerSubject: string,
    device: DeviceRegistration,
  ) {
    const key = `${provider}:${providerSubject}`;
    let userId = this.providerIndex.get(key);
    if (!userId) {
      userId = this.nextId("user");
      this.users.set(userId, { kind: "account", provider, providerSubject, displayName: null });
      this.providerIndex.set(key, userId);
    }
    const deviceId = this.nextId("device");
    this.devices.set(deviceId, { userId, registration: device });
    return Promise.resolve({ userId, deviceId });
  }

  linkProvider(
    _ctx: AppContext,
    userId: string,
    provider: ProviderKind,
    providerSubject: string,
  ): Promise<LinkProviderResult> {
    const key = `${provider}:${providerSubject}`;
    const existingOwner = this.providerIndex.get(key);
    if (existingOwner && existingOwner !== userId) return Promise.resolve("already_linked_elsewhere");
    const user = this.users.get(userId);
    if (!user) return Promise.resolve("already_linked_elsewhere");
    user.kind = "account";
    user.provider = provider;
    user.providerSubject = providerSubject;
    this.providerIndex.set(key, userId);
    return Promise.resolve("linked");
  }

  getProfile(userId: string): Promise<UserProfile | null> {
    const user = this.users.get(userId);
    return Promise.resolve(user ? { displayName: user.displayName, provider: user.provider } : null);
  }

  updateDisplayName(userId: string, displayName: string | null): Promise<void> {
    const user = this.users.get(userId);
    if (user) user.displayName = displayName;
    return Promise.resolve();
  }

  updatePushToken(userId: string, token: string | null): Promise<void> {
    for (const device of this.devices.values()) {
      if (device.userId === userId) device.pushToken = token;
    }
    return Promise.resolve();
  }

  listPushTargets(_ctx: AppContext): Promise<{ userId: string; token: string }[]> {
    const targets: { userId: string; token: string }[] = [];
    for (const device of this.devices.values()) {
      if (device.pushToken) targets.push({ userId: device.userId, token: device.pushToken });
    }
    return Promise.resolve(targets);
  }

  storeRefreshToken(hash: string, userId: string, deviceId: string, expiresAt: Date, rotatedFrom?: string) {
    const id = this.nextId("token");
    this.tokens.set(id, { id, hash, userId, deviceId, expiresAt, revokedAt: null, ...{ rotatedFrom } });
    return Promise.resolve(id);
  }

  findRefreshToken(hash: string) {
    for (const record of this.tokens.values()) {
      if (record.hash === hash) return Promise.resolve(record);
    }
    return Promise.resolve(null);
  }

  revokeRefreshToken(id: string) {
    const record = this.tokens.get(id);
    if (record) record.revokedAt = new Date();
    return Promise.resolve();
  }
}
