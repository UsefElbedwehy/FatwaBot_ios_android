import type { AppContext } from "./types.ts";

// Locale-resolved content models — mirrors docs/features/content-pipeline.md.
// Translation maps are resolved server-side (requested locale, falling back
// to Arabic) so clients receive plain strings, not {locale: value} maps.

export interface AzkarItem {
  id: string;
  sortOrder: number;
  arabicText: string;
  transliteration: string | null;
  translation: string | null;
  virtueNote: string | null;
  source: string;
  repeatCount: number;
}

export interface AzkarCategory {
  id: string;
  slug: string;
  name: string;
  sortOrder: number;
  items: AzkarItem[];
}

export interface AzkarCollection {
  version: number;
  categories: AzkarCategory[];
}

export interface Dua {
  id: string;
  sortOrder: number;
  title: string;
  arabicText: string;
  transliteration: string | null;
  translation: string | null;
  source: string;
}

export interface DuaCategory {
  id: string;
  slug: string;
  name: string;
  sortOrder: number;
  duas: Dua[];
}

export interface DuaCollection {
  version: number;
  categories: DuaCategory[];
}

export interface HadithCollectionSummary {
  id: string;
  slug: string;
  name: string;
  description: string;
  entryCount: number;
}

export interface HadithEntry {
  id: string;
  number: number;
  arabicText: string;
  translation: string | null;
  grading: string;
  benefitNote: string | null;
  source: string;
}

export interface HadithCollectionDetail {
  version: number;
  slug: string;
  name: string;
  description: string;
  entries: HadithEntry[];
}

export interface WirdTemplate {
  id: string;
  name: string;
  description: string;
  type: string;
  defaultTarget: number;
  defaultUnit: string;
  defaultFrequency: string;
}

export interface WirdTemplatesCollection {
  version: number;
  templates: WirdTemplate[];
}

/** Read-side repository for the content domain. Implemented by
 *  SupabaseContentRepo (production) and InMemoryContentRepo (tests). */
export interface ContentRepo {
  azkarCollection(ctx: AppContext): Promise<AzkarCollection>;
  duaCollection(ctx: AppContext): Promise<DuaCollection>;
  hadithCollections(ctx: AppContext): Promise<HadithCollectionSummary[]>;
  hadithCollectionDetail(ctx: AppContext, slug: string): Promise<HadithCollectionDetail | null>;
  wirdTemplates(ctx: AppContext): Promise<WirdTemplatesCollection>;
}
