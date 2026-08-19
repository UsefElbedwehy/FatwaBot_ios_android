import Link from "next/link";
import { getLocales, getStringPack, listStringPackLocales } from "@/lib/admin-api";
import { saveStringPackAction, setStringPackPublishedAction } from "@/lib/actions";
import { StringPackEditor } from "./StringPackEditor";

// String-pack editor (ADR-0011). The apps read every piece of UI copy from these
// packs, so this page is the only place the copy should be changed — editing
// config.string_packs by hand risks breaking the version contract that clients
// delta-sync on (see backend/functions/api/admin_strings_types.ts).

export default async function StringsPage({
  searchParams,
}: {
  searchParams: Promise<{ locale?: string; version?: string }>;
}) {
  const { locale: requestedLocale, version: requestedVersion } = await searchParams;

  // Two sources on purpose: the summary endpoint knows which locales HAVE a
  // pack, config.locales knows which locales the apps offer. A locale in the
  // second list but not the first is exactly the "no pack yet" case, and it
  // needs to be selectable or the first pack could never be created here.
  const [summaries, configured] = await Promise.all([listStringPackLocales(), getLocales()]);
  const directions = new Map(configured.map((l) => [l.locale, l.direction]));
  const displayNames = new Map(configured.map((l) => [l.locale, l.display_name]));
  const localeOptions = [...new Set([...summaries.map((s) => s.locale), ...configured.map((l) => l.locale)])]
    .sort((a, b) => a.localeCompare(b));

  const locale = requestedLocale && localeOptions.includes(requestedLocale)
    ? requestedLocale
    : localeOptions[0] ?? null;

  if (!locale) {
    return (
      <div className="max-w-3xl">
        <Header />
        <p className="mt-6 rounded-xl border border-dashed border-stone-300 bg-white p-8 text-center text-stone-500">
          No locales are configured yet. Add rows to <code className="font-mono text-xs">config.locales</code> first.
        </p>
      </div>
    );
  }

  const summary = summaries.find((s) => s.locale === locale) ?? null;
  const pinnedVersion = requestedVersion && /^\d+$/.test(requestedVersion) ? Number(requestedVersion) : undefined;
  const pack = await getStringPack(locale, pinnedVersion);

  const save = saveStringPackAction.bind(null, locale);
  const publishDraft = summary?.draftVersion !== null && summary?.draftVersion !== undefined
    ? setStringPackPublishedAction.bind(null, locale, summary.draftVersion, true)
    : null;
  const rollBackPublished = summary?.publishedVersion !== null && summary?.publishedVersion !== undefined
    ? setStringPackPublishedAction.bind(null, locale, summary.publishedVersion, false)
    : null;

  return (
    <div className="max-w-4xl">
      <Header />

      <nav aria-label="Locale" className="mt-5 flex flex-wrap gap-2">
        {localeOptions.map((option) => {
          const isActive = option === locale;
          const optionSummary = summaries.find((s) => s.locale === option);
          return (
            <Link
              key={option}
              href={`/configuration/strings?locale=${encodeURIComponent(option)}`}
              aria-current={isActive ? "page" : undefined}
              className={`rounded-lg border px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#7A2A2A] ${
                isActive
                  ? "border-[#7A2A2A] bg-[#7A2A2A] text-white"
                  : "border-stone-300 bg-white text-stone-700 hover:border-[#7A2A2A]"
              }`}
            >
              {displayNames.get(option) ?? option}
              <span className={`ms-2 font-mono text-xs ${isActive ? "text-white/70" : "text-stone-400"}`}>
                {option}
              </span>
              {!optionSummary && <span className="ms-2 text-xs italic">no pack</span>}
            </Link>
          );
        })}
      </nav>

      <div className="mt-4 flex flex-wrap items-center gap-x-6 gap-y-2 rounded-xl border border-stone-200 bg-white px-4 py-3 text-sm">
        <span>
          <span className="text-stone-500">Published:</span>{" "}
          {summary?.publishedVersion !== null && summary?.publishedVersion !== undefined
            ? <span className="font-medium text-emerald-700">v{summary.publishedVersion}</span>
            : <span className="text-stone-400">none</span>}
        </span>
        <span>
          <span className="text-stone-500">Draft:</span>{" "}
          {summary?.draftVersion !== null && summary?.draftVersion !== undefined
            ? <span className="font-medium text-amber-700">v{summary.draftVersion}</span>
            : <span className="text-stone-400">none</span>}
        </span>
        <span>
          <span className="text-stone-500">Editing:</span>{" "}
          {pack ? <span className="font-medium">v{pack.version} ({pack.published ? "published" : "draft"})</span> : (
            <span className="text-stone-400">new pack</span>
          )}
        </span>

        {publishDraft && (
          <form action={publishDraft} className="ms-auto">
            <button
              type="submit"
              className="rounded-lg bg-emerald-700 px-3 py-1.5 text-xs font-medium text-white hover:bg-emerald-800 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#7A2A2A]"
            >
              Publish draft v{summary?.draftVersion} as-is
            </button>
          </form>
        )}
        {rollBackPublished && (
          <form action={rollBackPublished} className={publishDraft ? "" : "ms-auto"}>
            <button
              type="submit"
              className="rounded-lg border border-stone-300 px-3 py-1.5 text-xs font-medium text-stone-600 hover:bg-stone-50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#7A2A2A]"
            >
              Unpublish v{summary?.publishedVersion}
            </button>
          </form>
        )}
      </div>

      {pack === null && (
        <p className="mt-4 rounded-xl border border-dashed border-stone-300 bg-white px-4 py-3 text-sm text-stone-600">
          <span className="font-medium">{locale}</span> has no string pack yet. Add keys below and save to create
          version 1 — the apps fall back to their bundled copy until a version is published.
        </p>
      )}
      {pinnedVersion !== undefined && pack !== null && (
        <p className="mt-4 rounded-xl border border-stone-200 bg-stone-50 px-4 py-3 text-sm text-stone-600">
          Viewing pinned v{pinnedVersion}. Saving still creates a new version on top of the newest one — it does not
          overwrite this version.{" "}
          <Link
            href={`/configuration/strings?locale=${encodeURIComponent(locale)}`}
            className="font-medium text-[#7A2A2A] underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#7A2A2A]"
          >
            Back to newest
          </Link>
        </p>
      )}

      <StringPackEditor
        // Remount when the operator switches locale or pins a version, so the
        // editor's local state can never belong to a different pack. It must NOT
        // be keyed on the fetched version: saving bumps that, and remounting
        // would wipe the "Published vN" confirmation the operator just earned.
        key={`${locale}:${pinnedVersion ?? "newest"}`}
        locale={locale}
        direction={directions.get(locale) ?? "ltr"}
        initialStrings={pack?.strings ?? {}}
        action={save}
        isNewPack={pack === null}
      />
    </div>
  );
}

function Header() {
  return (
    <div>
      <h1 className="text-2xl font-semibold">String packs</h1>
      <p className="mt-1 text-sm text-stone-500">
        Every piece of UI copy the apps render, per locale. Saving always creates a new version; clients only download
        a version higher than the one they already hold (ADR-0011).
      </p>
    </div>
  );
}
