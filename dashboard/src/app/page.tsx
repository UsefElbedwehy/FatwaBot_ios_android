import { fetchHealth } from "@/lib/api";
import { NAV_DOMAINS } from "@/lib/nav";

export default async function OverviewPage() {
  const health = await fetchHealth();

  return (
    <div className="max-w-4xl">
      <h1 className="text-2xl font-semibold">Overview</h1>
      <p className="mt-1 text-sm text-stone-500">
        Platform status and domain readiness. Domains activate milestone by milestone.
      </p>

      <div className="mt-6 rounded-xl border border-stone-200 bg-white p-5">
        <h2 className="text-sm font-medium text-stone-500">Backend API</h2>
        {health ? (
          <p className="mt-1 text-lg font-semibold text-emerald-700">
            Healthy · {health.version}
          </p>
        ) : (
          <p className="mt-1 text-lg font-semibold text-stone-400">
            Not connected — set NEXT_PUBLIC_API_BASE_URL after the Supabase project is provisioned
          </p>
        )}
      </div>

      <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {NAV_DOMAINS.filter((d) => d.slug !== "overview").map((domain) => (
          <div key={domain.slug} className="rounded-xl border border-stone-200 bg-white p-4">
            <div className="flex items-center justify-between">
              <h3 className="font-medium">{domain.title}</h3>
              <span className="rounded-full bg-stone-100 px-2 py-0.5 text-xs text-stone-500">
                {domain.milestone}
              </span>
            </div>
            <p className="mt-1 text-sm text-stone-500">{domain.description}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
