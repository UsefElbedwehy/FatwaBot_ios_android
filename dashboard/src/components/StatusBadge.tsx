export function StatusBadge({ published }: { published: boolean }) {
  return (
    <span
      className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium ${
        published ? "bg-emerald-100 text-emerald-700" : "bg-stone-100 text-stone-600"
      }`}
    >
      {published ? "Published" : "Draft"}
    </span>
  );
}
