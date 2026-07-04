import type { AppContext } from "../functions/api/types.ts";
import type {
  DeviceRegistration,
  IdentityRepo,
  RefreshTokenRecord,
} from "../functions/api/identity_types.ts";

export class InMemoryIdentityRepo implements IdentityRepo {
  users = new Map<string, { kind: "anonymous" | "account" }>();
  devices = new Map<string, { userId: string; registration: DeviceRegistration }>();
  tokens = new Map<string, RefreshTokenRecord & { hash: string }>();
  private counter = 0;

  private nextId(prefix: string): string {
    this.counter += 1;
    return `${prefix}-${this.counter.toString().padStart(4, "0")}`;
  }

  createAnonymousUser(_ctx: AppContext, device: DeviceRegistration) {
    const userId = this.nextId("user");
    const deviceId = this.nextId("device");
    this.users.set(userId, { kind: "anonymous" });
    this.devices.set(deviceId, { userId, registration: device });
    return Promise.resolve({ userId, deviceId });
  }

  userKind(userId: string) {
    return Promise.resolve(this.users.get(userId)?.kind ?? null);
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
