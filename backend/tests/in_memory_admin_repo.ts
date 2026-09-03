import type { AppContext } from "../functions/api/types.ts";
import type {
  AdminAuthRepo,
  AdminContentRepo,
  AdminContentRow,
  AdminUserRow,
  AdminUsersRepo,
  AuditEntry,
  AuditLogRepo,
} from "../functions/api/admin_types.ts";

let idCounter = 0;
function nextId(): string {
  idCounter += 1;
  return `row-${idCounter.toString().padStart(4, "0")}`;
}

export class InMemoryAdminContentRepo implements AdminContentRepo {
  rows = new Map<string, AdminContentRow[]>();

  seed(collection: string, rows: AdminContentRow[]) {
    this.rows.set(collection, rows);
  }

  list(_ctx: AppContext, collection: string): Promise<AdminContentRow[]> {
    return Promise.resolve(this.rows.get(collection) ?? []);
  }

  create(_ctx: AppContext, collection: string, fields: Record<string, unknown>): Promise<AdminContentRow> {
    const row: AdminContentRow = { id: nextId(), published: false, version: 1, fields: { ...fields } };
    const existing = this.rows.get(collection) ?? [];
    this.rows.set(collection, [...existing, row]);
    return Promise.resolve(row);
  }

  update(
    _ctx: AppContext,
    collection: string,
    id: string,
    fields: Record<string, unknown>,
  ): Promise<AdminContentRow | null> {
    const existing = this.rows.get(collection) ?? [];
    const index = existing.findIndex((r) => r.id === id);
    if (index === -1) return Promise.resolve(null);
    const current = existing[index];
    const updated: AdminContentRow = {
      ...current,
      version: current.published ? current.version + 1 : current.version,
      fields: { ...current.fields, ...fields },
    };
    const next = [...existing];
    next[index] = updated;
    this.rows.set(collection, next);
    return Promise.resolve(updated);
  }

  setPublished(
    _ctx: AppContext,
    collection: string,
    id: string,
    published: boolean,
  ): Promise<AdminContentRow | null> {
    const existing = this.rows.get(collection) ?? [];
    const index = existing.findIndex((r) => r.id === id);
    if (index === -1) return Promise.resolve(null);
    const updated: AdminContentRow = { ...existing[index], published };
    const next = [...existing];
    next[index] = updated;
    this.rows.set(collection, next);
    return Promise.resolve(updated);
  }
}

export class InMemoryAdminUsersRepo implements AdminUsersRepo {
  users: AdminUserRow[] = [];

  seed(users: AdminUserRow[]) {
    this.users = users;
  }

  list(
    _ctx: AppContext,
    query: string | null,
    limit: number,
    before: number | null,
  ): Promise<AdminUserRow[]> {
    let filtered = this.users;
    if (before !== null) filtered = filtered.filter((u) => u.createdAtEpochSeconds < before);
    if (query) {
      const needle = query.toLowerCase();
      filtered = filtered.filter((u) =>
        u.id === query || (u.displayName?.toLowerCase().includes(needle) ?? false)
      );
    }
    return Promise.resolve(
      [...filtered].sort((a, b) => b.createdAtEpochSeconds - a.createdAtEpochSeconds).slice(0, limit),
    );
  }
}

export class InMemoryAdminAuthRepo implements AdminAuthRepo {
  admins = new Map<string, { id: string; passwordHash: string }>(); // keyed by email

  findAdminByEmail(_ctx: AppContext, email: string) {
    return Promise.resolve(this.admins.get(email) ?? null);
  }
}

export class InMemoryAuditLogRepo implements AuditLogRepo {
  entries: (AuditEntry & { createdAtEpochSeconds: number })[] = [];
  private clock = 1_700_000_000;

  record(_ctx: AppContext, entry: AuditEntry): Promise<void> {
    this.clock += 1;
    this.entries.push({ ...entry, createdAtEpochSeconds: this.clock });
    return Promise.resolve();
  }

  list(_ctx: AppContext, collection?: string) {
    const filtered = collection ? this.entries.filter((e) => e.collection === collection) : this.entries;
    return Promise.resolve([...filtered].reverse());
  }
}
