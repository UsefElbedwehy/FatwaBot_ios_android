import Link from "next/link";
import { GAMIFICATION_COLLECTIONS } from "@/lib/collections";

export default function GamificationIndexPage() {
  return (
    <div className="max-w-3xl">
      <h1 className="text-2xl font-semibold">Gamification</h1>
      <p className="mt-1 text-sm text-stone-500">Streak rules, missions, badges, and leaderboards — all rules as data (ADR-0012).</p>

      <div className="mt-6 grid grid-cols-1 gap-3 sm:grid-cols-2">
        {GAMIFICATION_COLLECTIONS.map((c) => (
          <Link
            key={c.slug}
            href={`/content/${c.slug}`}
            className="rounded-xl border border-stone-200 bg-white p-4 hover:border-[#7A2A2A]"
          >
            <h2 className="font-medium">{c.title}</h2>
            <p className="mt-1 text-xs text-stone-500">{c.fields.length} fields</p>
          </Link>
        ))}
      </div>
    </div>
  );
}
