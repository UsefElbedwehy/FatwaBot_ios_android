import type { AppContext } from "../functions/api/types.ts";
import type {
  AdminStringsRepo,
  StringPackSummary,
  StringPackVersion,
} from "../functions/api/admin_strings_types.ts";

/** Mirrors config.string_packs: primary key (locale, version) within one app,
 * so a "save" appends a row and never mutates one. */
export class InMemoryAdminStringsRepo implements AdminStringsRepo {
  packs: StringPackVersion[] = [];

  seed(packs: StringPackVersion[]) {
    this.packs = packs.map((p) => ({ ...p, strings: { ...p.strings } }));
  }

  private forLocale(locale: string): StringPackVersion[] {
    return this.packs.filter((p) => p.locale === locale);
  }

  listLocales(_ctx: AppContext): Promise<StringPackSummary[]> {
    const locales = [...new Set(this.packs.map((p) => p.locale))].sort((a, b) => a.localeCompare(b));
    return Promise.resolve(locales.map((locale) => {
      const rows = this.forLocale(locale);
      const published = rows.filter((p) => p.published).map((p) => p.version);
      const drafts = rows.filter((p) => !p.published).map((p) => p.version);
      const newest = rows.reduce((a, b) => (b.version > a.version ? b : a));
      return {
        locale,
        publishedVersion: published.length ? Math.max(...published) : null,
        draftVersion: drafts.length ? Math.max(...drafts) : null,
        keyCount: Object.keys(newest.strings).length,
      };
    }));
  }

  getPack(_ctx: AppContext, locale: string, version: number | null): Promise<StringPackVersion | null> {
    const rows = this.forLocale(locale);
    if (rows.length === 0) return Promise.resolve(null);
    if (version !== null) return Promise.resolve(rows.find((p) => p.version === version) ?? null);
    return Promise.resolve(rows.reduce((a, b) => (b.version > a.version ? b : a)));
  }

  createVersion(
    _ctx: AppContext,
    locale: string,
    strings: Record<string, string>,
    published: boolean,
  ): Promise<StringPackVersion> {
    // max over ALL versions, published or not — a draft parked at
    // publishedMax + 1 must not be overwritten (migration 0024's bug class).
    const versions = this.forLocale(locale).map((p) => p.version);
    const pack: StringPackVersion = {
      locale,
      version: (versions.length ? Math.max(...versions) : 0) + 1,
      published,
      strings: { ...strings },
    };
    this.packs.push(pack);
    return Promise.resolve(pack);
  }

  setPublished(
    _ctx: AppContext,
    locale: string,
    version: number,
    published: boolean,
  ): Promise<StringPackVersion | null> {
    const index = this.packs.findIndex((p) => p.locale === locale && p.version === version);
    if (index === -1) return Promise.resolve(null);
    const updated = { ...this.packs[index], published };
    this.packs[index] = updated;
    return Promise.resolve(updated);
  }
}
