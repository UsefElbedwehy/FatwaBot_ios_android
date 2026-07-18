import { listAdminUsers } from "@/lib/admin-api";

function formatDate(epochSeconds: number): string {
  return new Date(epochSeconds * 1000).toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ query?: string }>;
}) {
  const { query } = await searchParams;
  const users = await listAdminUsers(query);

  return (
    <div className="max-w-4xl">
      <div>
        <h1 className="text-2xl font-semibold">Users</h1>
        <p className="mt-1 text-sm text-stone-500">{users.length} users{query ? ` matching "${query}"` : ""}</p>
      </div>

      <form className="mt-4 flex gap-2">
        <input
          type="text"
          name="query"
          defaultValue={query ?? ""}
          placeholder="Search by display name or user id…"
          className="w-full max-w-sm rounded-lg border border-stone-300 px-3 py-2 text-sm focus:border-[#7A2A2A] focus:outline-none"
        />
        <button
          type="submit"
          className="rounded-lg bg-[#7A2A2A] px-3 py-2 text-sm font-medium text-white hover:bg-[#5f2020]"
        >
          Search
        </button>
      </form>

      <div className="mt-6 overflow-hidden rounded-xl border border-stone-200 bg-white">
        <table className="w-full text-sm">
          <thead className="bg-stone-50 text-xs uppercase text-stone-500">
            <tr>
              <th className="px-4 py-2 text-start">Name</th>
              <th className="px-4 py-2 text-start">Kind</th>
              <th className="px-4 py-2 text-start">Provider</th>
              <th className="px-4 py-2 text-start">Country</th>
              <th className="px-4 py-2 text-start">Created</th>
            </tr>
          </thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.id} className="border-t border-stone-100 hover:bg-stone-50">
                <td className="px-4 py-2 font-medium">{u.displayName ?? <span className="text-stone-400">(no name)</span>}</td>
                <td className="px-4 py-2">
                  <span
                    className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium ${
                      u.kind === "account" ? "bg-emerald-100 text-emerald-700" : "bg-stone-100 text-stone-600"
                    }`}
                  >
                    {u.kind}
                  </span>
                </td>
                <td className="px-4 py-2 text-stone-500">{u.provider}</td>
                <td className="px-4 py-2 text-stone-500">{u.countryCode ?? "—"}</td>
                <td className="px-4 py-2 text-stone-500">{formatDate(u.createdAtEpochSeconds)}</td>
              </tr>
            ))}
            {users.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-6 text-center text-stone-400">
                  No users found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
