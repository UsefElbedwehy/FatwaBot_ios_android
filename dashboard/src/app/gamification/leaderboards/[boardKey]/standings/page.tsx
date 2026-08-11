import Link from "next/link";
import { notFound } from "next/navigation";
import { AdminApiError, listLeaderboardPeriods, listLeaderboardStandings } from "@/lib/admin-api";

/**
 * Full ranked standings for one board — every entry, every region, not just
 * the caller's own bucket the way the app's own leaderboard screen is scoped.
 * This is the page that answers "who won this period", which nothing else in
 * the dashboard could answer before (see the migration adding the endpoint
 * this calls: no admin UI has ever shown ranked entries, only the board's
 * *definition*).
 *
 * The period picker is a plain GET form — no client component needed, same
 * as the Users page's search box — so selecting a past period is just a
 * link/query-param, shareable and bookmarkable.
 */
export default async function LeaderboardStandingsPage({
  params,
  searchParams,
}: {
  params: Promise<{ boardKey: string }>;
  searchParams: Promise<{ period?: string }>;
}) {
  const { boardKey: key } = await params;
  const { period } = await searchParams;

  let standings;
  let periods: string[];
  try {
    [standings, periods] = await Promise.all([
      listLeaderboardStandings(key, period),
      listLeaderboardPeriods(key),
    ]);
  } catch (err) {
    if (err instanceof AdminApiError && err.status === 404) notFound();
    throw err;
  }

  return (
    <div className="max-w-4xl">
      <div>
        <Link href="/gamification/leaderboards" className="text-sm text-[#7A2A2A] hover:underline">
          ← All leaderboards
        </Link>
        <h1 className="mt-2 text-2xl font-semibold">{key}</h1>
        <p className="mt-1 text-sm text-stone-500">
          {standings.period} · {standings.periodKey}
          {standings.isCurrentPeriod ? " · current" : " · past period"} · {standings.entries.length} ranked
        </p>
      </div>

      <form className="mt-4 flex items-center gap-2">
        <select
          name="period"
          defaultValue={period ?? ""}
          className="rounded-lg border border-stone-300 px-3 py-2 text-sm focus:border-[#7A2A2A] focus:outline-none"
        >
          <option value="">Current period</option>
          {periods.map((p) => (
            <option key={p} value={p}>
              {p}
            </option>
          ))}
        </select>
        <button
          type="submit"
          className="rounded-lg bg-[#7A2A2A] px-3 py-2 text-sm font-medium text-white hover:bg-[#5f2020]"
        >
          View
        </button>
      </form>

      <div className="mt-6 overflow-hidden rounded-xl border border-stone-200 bg-white">
        <table className="w-full text-sm">
          <thead className="bg-stone-50 text-xs uppercase text-stone-500">
            <tr>
              <th className="px-4 py-2 text-start">Rank</th>
              <th className="px-4 py-2 text-start">Name</th>
              <th className="px-4 py-2 text-start">Region</th>
              <th className="px-4 py-2 text-start">Score</th>
            </tr>
          </thead>
          <tbody>
            {standings.entries.map((e) => (
              <tr
                key={`${e.bucket}-${e.rank}`}
                className={`border-t border-stone-100 hover:bg-stone-50 ${
                  e.rank === 1 ? "bg-amber-50" : ""
                }`}
              >
                <td className="px-4 py-2 font-medium">
                  {e.rank === 1 ? <span className="text-amber-700">#1</span> : `#${e.rank}`}
                </td>
                <td className="px-4 py-2 font-medium">{e.displayName}</td>
                <td className="px-4 py-2 text-stone-500">{e.country ?? e.city ?? "—"}</td>
                <td className="px-4 py-2 text-stone-500">{e.score}</td>
              </tr>
            ))}
            {standings.entries.length === 0 && (
              <tr>
                <td colSpan={4} className="px-4 py-6 text-center text-stone-400">
                  Nobody ranked in this period yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
