import Link from "next/link";

// Configuration domain index. Only string packs have an editor so far — the rest
// of the domain (remote config, flags, theme, Home layout) is still SQL-only, so
// it is listed as pending rather than linked to a dead page.
const PENDING = [
  { title: "Remote config & flags", note: "config.remote_config / config.feature_flags" },
  { title: "Theme tokens", note: "config.themes" },
  { title: "Home layout", note: "config.home_layouts" },
  { title: "Prayer defaults", note: "config.prayer_defaults" },
];

export default function ConfigurationIndexPage() {
  return (
    <div className="max-w-3xl">
      <h1 className="text-2xl font-semibold">Configuration</h1>
      <p className="mt-1 text-sm text-stone-500">
        Server-owned settings and copy. The apps read these at runtime, so changes ship without an app release
        (ADR-0011).
      </p>

      <div className="mt-6 grid grid-cols-1 gap-3 sm:grid-cols-2">
        <Link
          href="/configuration/strings"
          className="rounded-xl border border-stone-200 bg-white p-4 hover:border-[#7A2A2A] focus-visible:border-[#7A2A2A] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#7A2A2A]"
        >
          <h2 className="font-medium">String packs</h2>
          <p className="mt-1 text-xs text-stone-500">UI copy per locale, versioned and published to clients</p>
        </Link>

        {PENDING.map((item) => (
          <div key={item.title} className="rounded-xl border border-dashed border-stone-300 bg-white/50 p-4">
            <h2 className="font-medium text-stone-500">{item.title}</h2>
            <p className="mt-1 text-xs text-stone-400">No editor yet — {item.note}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
