import { notFound } from "next/navigation";
import { getCollectionDef } from "@/lib/collections";
import { getContentRow, getLocales } from "@/lib/admin-api";
import { setPublishedAction, updateContentAction } from "@/lib/actions";
import { StatusBadge } from "@/components/StatusBadge";
import { ContentForm } from "../ContentForm";

export default async function EditContentPage({
  params,
}: {
  params: Promise<{ collection: string; id: string }>;
}) {
  const { collection, id } = await params;
  const def = getCollectionDef(collection);
  if (!def) notFound();
  const [row, locales] = await Promise.all([getContentRow(collection, id), getLocales()]);
  if (!row) notFound();

  const action = updateContentAction.bind(null, collection, id);
  const publish = setPublishedAction.bind(null, collection, id, true);
  const unpublish = setPublishedAction.bind(null, collection, id, false);

  return (
    <div className="max-w-2xl">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Edit — {def.title}</h1>
        <StatusBadge published={row.published} />
      </div>
      <p className="mt-1 text-xs text-stone-500">
        v{row.version} · id {row.id}
      </p>

      <ContentForm def={def} locales={locales} action={action} initial={row.fields} submitLabel="Save" />

      <form action={row.published ? unpublish : publish} className="mt-4">
        <button
          type="submit"
          className={
            row.published
              ? "rounded-lg border border-stone-300 px-3 py-2 text-sm font-medium hover:bg-stone-50"
              : "rounded-lg bg-emerald-700 px-3 py-2 text-sm font-medium text-white hover:bg-emerald-800"
          }
        >
          {row.published ? "Unpublish" : "Publish"}
        </button>
      </form>
    </div>
  );
}
