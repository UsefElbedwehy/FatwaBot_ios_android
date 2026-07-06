import Link from "next/link";
import { CONTENT_COLLECTIONS } from "@/lib/collections";

export default function ContentIndexPage() {
  return (
    <div className="max-w-3xl">
      <h1 className="text-2xl font-semibold">Content</h1>
      <p className="mt-1 text-sm text-stone-500">Azkar, duas, hadith collections, and wird templates.</p>

      <div className="mt-6 grid grid-cols-1 gap-3 sm:grid-cols-2">
        {CONTENT_COLLECTIONS.map((c) => (
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
