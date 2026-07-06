import Link from "next/link";
import { notFound } from "next/navigation";
import { displayTitle, getCollectionDef } from "@/lib/collections";
import { listContent } from "@/lib/admin-api";
import { StatusBadge } from "@/components/StatusBadge";

export default async function CollectionListPage({
  params,
}: {
  params: Promise<{ collection: string }>;
}) {
  const { collection } = await params;
  const def = getCollectionDef(collection);
  if (!def) notFound();
  const rows = await listContent(collection);

  return (
    <div className="max-w-4xl">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">{def.title}</h1>
          <p className="mt-1 text-sm text-stone-500">{rows.length} rows</p>
        </div>
        <Link
          href={`/content/${collection}/new`}
          className="rounded-lg bg-[#7A2A2A] px-3 py-2 text-sm font-medium text-white hover:bg-[#5f2020]"
        >
          New
        </Link>
      </div>

      <div className="mt-6 overflow-hidden rounded-xl border border-stone-200 bg-white">
        <table className="w-full text-sm">
          <thead className="bg-stone-50 text-xs uppercase text-stone-500">
            <tr>
              <th className="px-4 py-2 text-start">Name</th>
              <th className="px-4 py-2 text-start">Status</th>
              <th className="px-4 py-2 text-start">Version</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.id} className="border-t border-stone-100 hover:bg-stone-50">
                <td className="px-4 py-2">
                  <Link href={`/content/${collection}/${row.id}`} className="font-medium text-[#7A2A2A] hover:underline">
                    {displayTitle(def, row)}
                  </Link>
                </td>
                <td className="px-4 py-2">
                  <StatusBadge published={row.published} />
                </td>
                <td className="px-4 py-2 text-stone-500">v{row.version}</td>
              </tr>
            ))}
            {rows.length === 0 && (
              <tr>
                <td colSpan={3} className="px-4 py-6 text-center text-stone-400">
                  No rows yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
