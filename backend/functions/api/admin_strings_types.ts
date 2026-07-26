import type { AppContext } from "./types.ts";

// Admin surface for config.string_packs (migration 0002, ADR-0011).
//
// Deliberately NOT modelled as an AdminContentRow / ADMIN_COLLECTIONS entry:
// string packs are keyed by (app_id, locale, version) with no uuid id, and
// `version` is part of the identity rather than an edit counter. The generic
// content CRUD would edit a row in place — which is exactly what the client
// delta-sync contract forbids (see below).
//
// CLIENT CONTRACT (ConfigRepo.publishedStringPack): clients receive the
// HIGHEST published version for a locale and skip the payload entirely when
// `version <= since_version`. Therefore:
//   * Publishing an edit means INSERTING A NEW ROW at a higher version. An
//     in-place edit of an already-published version never reaches a client
//     that already holds that version.
//   * Multiple published versions coexist; the max wins. Publishing does not
//     unpublish anything.
//   * The next version is max(version) + 1 across ALL rows for the
//     (app_id, locale) pair — published or not. Using max(published)+1 would
//     collide with an unpublished draft parked at that number (the bug called
//     out in migration 0024).

/** One row per locale that has at least one pack — the editor's locale picker. */
export interface StringPackSummary {
  locale: string;
  /** Highest published version, or null when the locale has only drafts. */
  publishedVersion: number | null;
  /** Highest unpublished version, or null when every version is published. */
  draftVersion: number | null;
  /** Key count of the highest version overall (what the editor opens on). */
  keyCount: number;
}

/** A single (locale, version) pack. `strings` is a flat map — the mobile
 * clients decode it as [String: String], so non-string values are rejected at
 * the handler boundary rather than stored. */
export interface StringPackVersion {
  locale: string;
  version: number;
  published: boolean;
  strings: Record<string, string>;
}

export interface AdminStringsRepo {
  /** Summary per locale, ordered by locale. */
  listLocales(ctx: AppContext): Promise<StringPackSummary[]>;
  /** `version === null` returns the highest version for the locale (draft if
   * one sits above the published one), so the editor opens on newest state. */
  getPack(ctx: AppContext, locale: string, version: number | null): Promise<StringPackVersion | null>;
  /** Inserts max(version) + 1 for the locale — never mutates an existing row. */
  createVersion(
    ctx: AppContext,
    locale: string,
    strings: Record<string, string>,
    published: boolean,
  ): Promise<StringPackVersion>;
  /** Flips `published` on an existing (locale, version). Null when absent. */
  setPublished(
    ctx: AppContext,
    locale: string,
    version: number,
    published: boolean,
  ): Promise<StringPackVersion | null>;
}
