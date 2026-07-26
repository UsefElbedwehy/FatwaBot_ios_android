import { listAuditLog } from "@/lib/admin-api";
import { CONTENT_COLLECTIONS } from "@/lib/collections";

export default async function AuditLogPage({
  searchParams,
}: {
  searchParams: Promise<{ collection?: string }>;
}) {
  const { collection } = await searchParams;
  const entries = await listAuditLog(collection);

  return (
    <div className="max-w-4xl">
      <h1 className="text-2xl font-semibold">Audit log</h1>
      <p className="mt-1 text-sm text-stone-500">Every admin mutation, most recent first.</p>

      <form className="mt-4 flex items-center gap-2" method="get">
        <select
          name="collection"
          defaultValue={collection ?? ""}
          className="rounded-lg border border-stone-300 px-3 py-2 text-sm"
        >
          <option value="">All collections</option>
          {CONTENT_COLLECTIONS.map((c) => (
            <option key={c.slug} value={c.slug}>
              {c.title}
            </option>
          ))}
          {/* Not a CONTENT_COLLECTIONS entry — string packs are keyed by
              (locale, version) rather than a row id, so they have their own
              editor and audit rows (collection "string-packs"). */}
          <option value="string-packs">String Packs</option>
        </select>
        <button type="submit" className="rounded-lg border border-stone-300 px-3 py-2 text-sm hover:bg-stone-50">
          Filter
        </button>
      </form>

      <div className="mt-4 overflow-hidden rounded-xl border border-stone-200 bg-white">
        <table className="w-full text-sm">
          <thead className="bg-stone-50 text-xs uppercase text-stone-500">
            <tr>
              <th className="px-4 py-2 text-start">When</th>
              <th className="px-4 py-2 text-start">Admin</th>
              <th className="px-4 py-2 text-start">Collection</th>
              <th className="px-4 py-2 text-start">Row</th>
              <th className="px-4 py-2 text-start">Action</th>
            </tr>
          </thead>
          <tbody>
            {entries.map((e, i) => (
              <tr key={`${e.rowId}-${e.createdAtEpochSeconds}-${i}`} className="border-t border-stone-100">
                <td className="px-4 py-2 text-stone-500">
                  {new Date(e.createdAtEpochSeconds * 1000).toLocaleString()}
                </td>
                <td className="px-4 py-2 font-mono text-xs">{e.adminId}</td>
                <td className="px-4 py-2">{e.collection}</td>
                <td className="px-4 py-2 font-mono text-xs">{e.rowId}</td>
                <td className="px-4 py-2 capitalize">{e.action}</td>
              </tr>
            ))}
            {entries.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-6 text-center text-stone-400">
                  No activity yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
