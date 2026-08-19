import Link from "next/link";
import { displayTitle, getCollectionDef } from "@/lib/collections";
import { listContent } from "@/lib/admin-api";
import { StatusBadge } from "@/components/StatusBadge";

/** Index of every leaderboard board, linking each to its standings — separate
 * from /content/leaderboard-defs, which edits a board's *definition* (period,
 * metric, rewards copy) but has never shown who is actually ranked on it. */
export default async function LeaderboardsIndexPage() {
  const def = getCollectionDef("leaderboard-defs");
  const rows = def ? await listContent("leaderboard-defs") : [];

  return (
    <div className="max-w-4xl">
      <div>
        <Link href="/gamification" className="text-sm text-[#7A2A2A] hover:underline">
          ← Gamification
        </Link>
        <h1 className="mt-2 text-2xl font-semibold">Leaderboard Standings</h1>
        <p className="mt-1 text-sm text-stone-500">
          Who is actually ranked on each board — pick one to see the current period, or a past one.
        </p>
      </div>

      <div className="mt-6 overflow-hidden rounded-xl border border-stone-200 bg-white">
        <table className="w-full text-sm">
          <thead className="bg-stone-50 text-xs uppercase text-stone-500">
            <tr>
              <th className="px-4 py-2 text-start">Board</th>
              <th className="px-4 py-2 text-start">Key</th>
              <th className="px-4 py-2 text-start">Scope</th>
              <th className="px-4 py-2 text-start">Period</th>
              <th className="px-4 py-2 text-start">Status</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => {
              const key = row.fields.key as string;
              return (
                <tr key={row.id} className="border-t border-stone-100 hover:bg-stone-50">
                  <td className="px-4 py-2">
                    <Link
                      href={`/gamification/leaderboards/${encodeURIComponent(key)}/standings`}
                      className="font-medium text-[#7A2A2A] hover:underline"
                    >
                      {def ? displayTitle(def, row) : key}
                    </Link>
                  </td>
                  <td className="px-4 py-2 text-stone-500">{key}</td>
                  <td className="px-4 py-2 text-stone-500">{String(row.fields.scope ?? "—")}</td>
                  <td className="px-4 py-2 text-stone-500">{String(row.fields.period ?? "—")}</td>
                  <td className="px-4 py-2">
                    <StatusBadge published={row.published} />
                  </td>
                </tr>
              );
            })}
            {rows.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-6 text-center text-stone-400">
                  No leaderboard boards yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
