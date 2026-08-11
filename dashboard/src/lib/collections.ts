// Static field schema for the content editor (docs/features/content-pipeline.md).
// This describes the dashboard's own form rendering, not a product-facing config
// surface, so it is hardcoded rather than server-driven (ADR-0015 applies to the
// mobile-facing configurability layer, not this internal tool's UI definition).

export type FieldKind =
  | "text"
  | "optional-text"
  | "textarea"
  | "number"
  | "boolean"
  | "json"
  | "array"
  | "translatable"
  | "translatable-textarea";

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

// Gamification (ADR-0012: streaks/missions/badges/leaderboards as admin-authored
// data, docs/features/gamification.md, docs/features/leaderboard.md). Complex
// nested structures (point formulas, criteria/eligibility objects) are edited
// as raw JSON — they're data, not code, so a textarea + JSON.parse is enough;
// a bad edit is fixable by re-editing the row, not a deploy.
export const GAMIFICATION_COLLECTIONS: CollectionDef[] = [
  {
    slug: "streak-defs",
    title: "Streak Definitions",
    titleField: "name_translations",
    fields: [
      { key: "key", label: "Key", kind: "text" },
      { key: "name_translations", label: "Name", kind: "translatable" },
      { key: "event_types", label: "Qualifying event types", kind: "array" },
      { key: "required_daily_count", label: "Required daily count", kind: "number" },
      { key: "day_boundary_type", label: "Day boundary type (fixed_local_time | midnight)", kind: "text" },
      { key: "day_boundary_local_time", label: "Day boundary local time (HH:MM)", kind: "text" },
      { key: "grace_allowance", label: "Grace allowance", kind: "number" },
      { key: "grace_period_days", label: "Grace period (days)", kind: "number" },
      { key: "enabled", label: "Enabled", kind: "boolean" },
    ],
  },
  {
    slug: "missions",
    title: "Missions",
    titleField: "name_translations",
    fields: [
      { key: "key", label: "Key", kind: "text" },
      { key: "name_translations", label: "Name", kind: "translatable" },
      { key: "description_translations", label: "Description", kind: "translatable-textarea" },
      { key: "event_type", label: "Event type", kind: "text" },
      { key: "target_count", label: "Target count", kind: "number" },
      { key: "progress_window", label: "Window (daily | weekly | lifetime)", kind: "text" },
      { key: "schedule", label: "Schedule (daily | weekly | seasonal)", kind: "text" },
      { key: "reward_translations", label: "Reward", kind: "translatable-textarea" },
      { key: "starts_at", label: "Starts at (ISO 8601, optional)", kind: "optional-text" },
      { key: "ends_at", label: "Ends at (ISO 8601, optional)", kind: "optional-text" },
    ],
  },
  {
    slug: "badges",
    title: "Badges",
    titleField: "name_translations",
    fields: [
      { key: "key", label: "Key", kind: "text" },
      { key: "name_translations", label: "Name", kind: "translatable" },
      { key: "description_translations", label: "Description", kind: "translatable-textarea" },
      { key: "icon_ref", label: "Icon reference", kind: "text" },
      { key: "event_type", label: "Event type", kind: "text" },
      { key: "target_count", label: "Target count", kind: "number" },
      { key: "progress_window", label: "Window (daily | weekly | lifetime)", kind: "text" },
      { key: "hidden_until_earned", label: "Hidden until earned", kind: "boolean" },
    ],
  },
  {
    slug: "leaderboard-defs",
    title: "Leaderboard Definitions",
    titleField: "name_translations",
    fields: [
      { key: "key", label: "Key", kind: "text" },
      { key: "name_translations", label: "Name", kind: "translatable" },
      { key: "scope", label: "Scope (global | country | city)", kind: "text" },
      { key: "period", label: "Period (weekly | monthly | halfyearly | seasonal | lifetime | challenge)", kind: "text" },
      { key: "metric", label: "Metric (point formula JSON)", kind: "json" },
      { key: "eligibility", label: "Eligibility (JSON)", kind: "json" },
      { key: "tie_breakers", label: "Tie-breakers (ordered)", kind: "array" },
      { key: "visibility", label: "Visibility (public | opt_in_only)", kind: "text" },
      { key: "display_requirements", label: "Display requirements (JSON)", kind: "json" },
      { key: "rewards_translations", label: "Rewards", kind: "translatable-textarea" },
      { key: "season_starts_at", label: "Season starts at (ISO 8601, optional)", kind: "optional-text" },
      { key: "season_ends_at", label: "Season ends at (ISO 8601, optional)", kind: "optional-text" },
      { key: "enabled", label: "Enabled", kind: "boolean" },
    ],
  },
];

// Notifications (ADR-0013: catalog + templates + campaign engine, docs/features/notification-campaigns.md).
export const NOTIFICATION_COLLECTIONS: CollectionDef[] = [
  {
    slug: "notification-types",
    title: "Notification Types",
    titleField: "name_translations",
    fields: [
      { key: "key", label: "Key", kind: "text" },
      { key: "category", label: "Category (worship | gamification | campaign)", kind: "text" },
      { key: "name_translations", label: "Name", kind: "translatable" },
      { key: "help_text_translations", label: "Help text", kind: "translatable-textarea" },
      { key: "default_enabled", label: "Default enabled", kind: "boolean" },
      { key: "offset_configurable", label: "Offset configurable", kind: "boolean" },
      { key: "delivery_class", label: "Delivery class (local_computed | remote)", kind: "text" },
    ],
  },
  {
    slug: "notification-templates",
    title: "Notification Templates",
    titleField: "title_translations",
    fields: [
      { key: "key", label: "Key", kind: "text" },
      { key: "locale", label: "Locale", kind: "text" },
      { key: "variant", label: "Variant", kind: "text" },
      { key: "notification_type_key", label: "Notification type key", kind: "text" },
      { key: "title_translations", label: "Title", kind: "translatable" },
      { key: "body_translations", label: "Body", kind: "translatable-textarea" },
    ],
  },
  {
    slug: "notification-campaigns",
    title: "Notification Campaigns",
    titleField: "key",
    fields: [
      { key: "key", label: "Key", kind: "text" },
      { key: "template_key", label: "Template key", kind: "text" },
      { key: "kind", label: "Kind (one_time | recurring | event_triggered | emergency)", kind: "text" },
      { key: "schedule", label: "Schedule (JSON, shape varies by kind)", kind: "json" },
      { key: "segment", label: "Segment (JSON)", kind: "json" },
      { key: "daily_cap_override", label: "Daily cap override", kind: "number" },
      { key: "requires_dual_confirmation", label: "Requires dual confirmation (emergency sends)", kind: "boolean" },
    ],
  },
];

const ALL_COLLECTIONS: CollectionDef[] = [
  ...CONTENT_COLLECTIONS,
  ...GAMIFICATION_COLLECTIONS,
  ...NOTIFICATION_COLLECTIONS,
];

export function getCollectionDef(slug: string): CollectionDef | undefined {
  return ALL_COLLECTIONS.find((c) => c.slug === slug);
}

export function displayTitle(def: CollectionDef, row: { fields: Record<string, unknown> }): string {
  const value = row.fields[def.titleField];
  if (value && typeof value === "object") {
    const translations = value as Record<string, string>;
    return translations.ar ?? translations.en ?? Object.values(translations)[0] ?? "(untitled)";
  }
  return typeof value === "string" && value.length > 0 ? value : "(untitled)";
}
