// Static field schema for the content editor (docs/features/content-pipeline.md).
// This describes the dashboard's own form rendering, not a product-facing config
// surface, so it is hardcoded rather than server-driven (ADR-0015 applies to the
// mobile-facing configurability layer, not this internal tool's UI definition).

export type FieldKind = "text" | "textarea" | "number" | "translatable" | "translatable-textarea";

export interface FieldDef {
  key: string;
  label: string;
  kind: FieldKind;
}

export interface CollectionDef {
  slug: string;
  title: string;
  /** Field whose value (or translation map) is shown as the row's display name in list tables. */
  titleField: string;
  fields: FieldDef[];
}

export const CONTENT_COLLECTIONS: CollectionDef[] = [
  {
    slug: "azkar-categories",
    title: "Azkar Categories",
    titleField: "name_translations",
    fields: [
      { key: "slug", label: "Slug", kind: "text" },
      { key: "name_translations", label: "Name", kind: "translatable" },
      { key: "sort_order", label: "Sort order", kind: "number" },
    ],
  },
  {
    slug: "azkar-items",
    title: "Azkar Items",
    titleField: "arabic_text",
    fields: [
      { key: "category_id", label: "Category ID", kind: "text" },
      { key: "sort_order", label: "Sort order", kind: "number" },
      { key: "arabic_text", label: "Arabic text (canonical)", kind: "textarea" },
      { key: "transliteration_translations", label: "Transliteration", kind: "translatable-textarea" },
      { key: "translation_translations", label: "Translation", kind: "translatable-textarea" },
      { key: "virtue_note_translations", label: "Virtue note", kind: "translatable-textarea" },
      { key: "source", label: "Source", kind: "text" },
      { key: "repeat_count", label: "Repeat count", kind: "number" },
    ],
  },
  {
    slug: "dua-categories",
    title: "Dua Categories",
    titleField: "name_translations",
    fields: [
      { key: "slug", label: "Slug", kind: "text" },
      { key: "name_translations", label: "Name", kind: "translatable" },
      { key: "sort_order", label: "Sort order", kind: "number" },
    ],
  },
  {
    slug: "duas",
    title: "Duas",
    titleField: "title_translations",
    fields: [
      { key: "category_id", label: "Category ID", kind: "text" },
      { key: "sort_order", label: "Sort order", kind: "number" },
      { key: "title_translations", label: "Title", kind: "translatable" },
      { key: "arabic_text", label: "Arabic text (canonical)", kind: "textarea" },
      { key: "transliteration_translations", label: "Transliteration", kind: "translatable-textarea" },
      { key: "translation_translations", label: "Translation", kind: "translatable-textarea" },
      { key: "source", label: "Source", kind: "text" },
    ],
  },
  {
    slug: "hadith-collections",
    title: "Hadith Collections",
    titleField: "name_translations",
    fields: [
      { key: "slug", label: "Slug", kind: "text" },
      { key: "name_translations", label: "Name", kind: "translatable" },
      { key: "description_translations", label: "Description", kind: "translatable-textarea" },
      { key: "sort_order", label: "Sort order", kind: "number" },
    ],
  },
  {
    slug: "hadith-entries",
    title: "Hadith Entries",
    titleField: "arabic_text",
    fields: [
      { key: "collection_id", label: "Collection ID", kind: "text" },
      { key: "number", label: "Number", kind: "number" },
      { key: "arabic_text", label: "Arabic text (canonical)", kind: "textarea" },
      { key: "translation_translations", label: "Translation", kind: "translatable-textarea" },
      { key: "grading", label: "Grading", kind: "text" },
      { key: "benefit_note_translations", label: "Benefit note", kind: "translatable-textarea" },
      { key: "source", label: "Source", kind: "text" },
    ],
  },
  {
    slug: "wird-templates",
    title: "Wird Templates",
    titleField: "name_translations",
    fields: [
      { key: "name_translations", label: "Name", kind: "translatable" },
      { key: "description_translations", label: "Description", kind: "translatable-textarea" },
      { key: "type", label: "Type", kind: "text" },
      { key: "default_target", label: "Default target", kind: "number" },
      { key: "default_unit", label: "Default unit", kind: "text" },
      { key: "default_frequency", label: "Default frequency", kind: "text" },
      { key: "sort_order", label: "Sort order", kind: "number" },
    ],
  },
];

export function getCollectionDef(slug: string): CollectionDef | undefined {
  return CONTENT_COLLECTIONS.find((c) => c.slug === slug);
}

export function displayTitle(def: CollectionDef, row: { fields: Record<string, unknown> }): string {
  const value = row.fields[def.titleField];
  if (value && typeof value === "object") {
    const translations = value as Record<string, string>;
    return translations.ar ?? translations.en ?? Object.values(translations)[0] ?? "(untitled)";
  }
  return typeof value === "string" && value.length > 0 ? value : "(untitled)";
}
