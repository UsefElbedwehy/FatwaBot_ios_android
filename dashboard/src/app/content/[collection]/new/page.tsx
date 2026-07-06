import { notFound } from "next/navigation";
import { getCollectionDef } from "@/lib/collections";
import { getLocales } from "@/lib/admin-api";
import { createContentAction } from "@/lib/actions";
import { ContentForm } from "../ContentForm";

export default async function NewContentPage({
  params,
}: {
  params: Promise<{ collection: string }>;
}) {
  const { collection } = await params;
  const def = getCollectionDef(collection);
  if (!def) notFound();
  const locales = await getLocales();
  const action = createContentAction.bind(null, collection);

  return (
    <div className="max-w-2xl">
      <h1 className="text-2xl font-semibold">New — {def.title}</h1>
      <ContentForm def={def} locales={locales} action={action} submitLabel="Create draft" />
    </div>
  );
}
