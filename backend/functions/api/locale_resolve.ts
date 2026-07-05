// Shared helper: resolve a {locale: value} translations map to a plain string
// (ADR-0014 — Arabic canonical, server resolves so clients get plain text).

type Translations = Record<string, string> | null | undefined;

/** For name/title/description-style fields that should always have Arabic. */
export function resolveRequired(translations: Translations, locale: string, fallback = "ar"): string {
  if (!translations) return "";
  return translations[locale] ?? translations[fallback] ?? Object.values(translations)[0] ?? "";
}

/** For translation/virtue-note/benefit-note fields with no guaranteed fallback. */
export function resolveOptional(translations: Translations, locale: string): string | null {
  if (!translations) return null;
  const value = translations[locale];
  return value && value.length > 0 ? value : null;
}
