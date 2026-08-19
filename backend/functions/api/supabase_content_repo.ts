import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { resolveOptional, resolveRequired } from "./locale_resolve.ts";
import type { AppContext } from "./types.ts";
import type {
  AzkarCollection,
  ContentRepo,
  DuaCollection,
  HadithCollectionDetail,
  HadithCollectionSummary,
  WirdTemplatesCollection,
} from "./content_types.ts";

export class SupabaseContentRepo implements ContentRepo {
  constructor(private readonly db: SupabaseClient) {}

  async azkarCollection(ctx: AppContext): Promise<AzkarCollection> {
    const locale = ctx.locale;
    const [{ data: categories, error: catError }, { data: items, error: itemError }] = await Promise.all([
      this.db.schema("content").from("azkar_categories")
        .select("id,slug,name_translations,sort_order,version")
        .eq("app_id", ctx.appId).eq("published", true).order("sort_order"),
      this.db.schema("content").from("azkar_items")
        .select(
          "id,category_id,sort_order,title_translations,arabic_text,transliteration_translations,translation_translations,virtue_note_translations,source,repeat_count,version",
        )
        .eq("app_id", ctx.appId).eq("published", true).order("sort_order"),
    ]);
    if (catError) throw catError;
    if (itemError) throw itemError;

    const version = Math.max(
      0,
      ...(categories ?? []).map((c) => c.version),
      ...(items ?? []).map((i) => i.version),
    );

    const categoryList = (categories ?? []).map((c) => ({
      id: c.id,
      slug: c.slug,
      name: resolveRequired(c.name_translations, locale),
      sortOrder: c.sort_order,
      items: (items ?? [])
        .filter((i) => i.category_id === c.id)
        .map((i) => ({
          id: i.id,
          sortOrder: i.sort_order,
          // Optional by design: an untitled entry renders as it always has.
          // Titling 94 supplications is reviewed religious content and lands
          // separately, so the reader has to handle both states indefinitely.
          title: resolveOptional(i.title_translations, locale),
          arabicText: i.arabic_text,
          transliteration: resolveOptional(i.transliteration_translations, locale),
          translation: resolveOptional(i.translation_translations, locale),
          virtueNote: resolveOptional(i.virtue_note_translations, locale),
          source: i.source,
          repeatCount: i.repeat_count,
        })),
    }));

    return { version, categories: categoryList };
  }

  async duaCollection(ctx: AppContext): Promise<DuaCollection> {
    const locale = ctx.locale;
    const [{ data: categories, error: catError }, { data: duas, error: duaError }] = await Promise.all([
      this.db.schema("content").from("dua_categories")
        .select("id,slug,name_translations,sort_order,version")
        .eq("app_id", ctx.appId).eq("published", true).order("sort_order"),
      this.db.schema("content").from("duas")
        .select(
          "id,category_id,sort_order,title_translations,arabic_text,transliteration_translations,translation_translations,source,version",
        )
        .eq("app_id", ctx.appId).eq("published", true).order("sort_order"),
    ]);
    if (catError) throw catError;
    if (duaError) throw duaError;

    const version = Math.max(
      0,
      ...(categories ?? []).map((c) => c.version),
      ...(duas ?? []).map((d) => d.version),
    );

    const categoryList = (categories ?? []).map((c) => ({
      id: c.id,
      slug: c.slug,
      name: resolveRequired(c.name_translations, locale),
      sortOrder: c.sort_order,
      duas: (duas ?? [])
        .filter((d) => d.category_id === c.id)
        .map((d) => ({
          id: d.id,
          sortOrder: d.sort_order,
          title: resolveRequired(d.title_translations, locale),
          arabicText: d.arabic_text,
          transliteration: resolveOptional(d.transliteration_translations, locale),
          translation: resolveOptional(d.translation_translations, locale),
          source: d.source,
        })),
    }));

    return { version, categories: categoryList };
  }

  async hadithCollections(ctx: AppContext): Promise<HadithCollectionSummary[]> {
    const locale = ctx.locale;
    const { data, error } = await this.db
      .schema("content").from("hadith_collections")
      .select("id,slug,name_translations,description_translations,hadith_entries(count)")
      .eq("app_id", ctx.appId).eq("published", true)
      // Count only what the detail endpoint will actually serve. Without this
      // the embedded count includes unpublished rows, so the list advertised
      // "بلوغ المرام · 1564" while opening it returned nothing — every entry
      // seeded by 0025 is `review_status = 'pending'` until a scholar approves
      // it. A filter on an embedded resource narrows the aggregate without
      // dropping the parent, so a collection with nothing approved yet still
      // appears, honestly, as 0.
      .eq("hadith_entries.published", true)
      .order("sort_order");
    if (error) throw error;
    return (data ?? []).map((c) => ({
      id: c.id,
      slug: c.slug,
      name: resolveRequired(c.name_translations, locale),
      description: resolveRequired(c.description_translations, locale),
      entryCount: c.hadith_entries?.[0]?.count ?? 0,
    }));
  }

  async hadithCollectionDetail(ctx: AppContext, slug: string): Promise<HadithCollectionDetail | null> {
    const locale = ctx.locale;
    const { data: collection, error: collectionError } = await this.db
      .schema("content").from("hadith_collections")
      .select("id,slug,name_translations,description_translations,version")
      .eq("app_id", ctx.appId).eq("published", true).eq("slug", slug)
      .maybeSingle();
    if (collectionError) throw collectionError;
    if (!collection) return null;

    // PostgREST caps a single response at ~1000 rows, so a large collection
    // (e.g. Bukhari ~7500) would be silently truncated. Page through until a
    // short page signals the end — the app expects the whole collection.
    interface HadithEntryRow {
      id: string;
      number: number;
      arabic_text: string;
      translation_translations: Record<string, string> | null;
      grading: string;
      benefit_note_translations: Record<string, string> | null;
      source: string;
      version: number;
    }
    const PAGE = 1000;
    const entries: HadithEntryRow[] = [];
    for (let from = 0;; from += PAGE) {
      const { data: page, error: entriesError } = await this.db
        .schema("content").from("hadith_entries")
        .select(
          "id,number,arabic_text,translation_translations,grading,benefit_note_translations,source,version",
        )
        .eq("app_id", ctx.appId).eq("published", true).eq("collection_id", collection.id)
        .order("number").range(from, from + PAGE - 1);
      if (entriesError) throw entriesError;
      if (!page || page.length === 0) break;
      entries.push(...(page as HadithEntryRow[]));
      if (page.length < PAGE) break;
    }

    const version = Math.max(collection.version, 0, ...entries.map((e) => e.version));

    return {
      version,
      slug: collection.slug,
      name: resolveRequired(collection.name_translations, locale),
      description: resolveRequired(collection.description_translations, locale),
      entries: (entries ?? []).map((e) => ({
        id: e.id,
        number: e.number,
        arabicText: e.arabic_text,
        translation: resolveOptional(e.translation_translations, locale),
        grading: e.grading,
        benefitNote: resolveOptional(e.benefit_note_translations, locale),
        source: e.source,
      })),
    };
  }

  async wirdTemplates(ctx: AppContext): Promise<WirdTemplatesCollection> {
    const locale = ctx.locale;
    const { data, error } = await this.db
      .schema("content").from("wird_templates")
      .select(
        "id,name_translations,description_translations,type,default_target,default_unit,default_frequency,version",
      )
      .eq("app_id", ctx.appId).eq("published", true).order("sort_order");
    if (error) throw error;

    const version = Math.max(0, ...(data ?? []).map((t) => t.version));
    return {
      version,
      templates: (data ?? []).map((t) => ({
        id: t.id,
        name: resolveRequired(t.name_translations, locale),
        description: resolveRequired(t.description_translations, locale),
        type: t.type,
        defaultTarget: t.default_target,
        defaultUnit: t.default_unit,
        defaultFrequency: t.default_frequency,
      })),
    };
  }
}
