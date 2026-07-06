import { notFound } from "next/navigation";
import { NAV_DOMAINS } from "@/lib/nav";

export function generateStaticParams() {
  return NAV_DOMAINS.filter((d) => !d.implemented).map((d) => ({ domain: d.slug }));
}

export default async function DomainPlaceholderPage({
  params,
}: {
  params: Promise<{ domain: string }>;
}) {
  const { domain: slug } = await params;
  const domain = NAV_DOMAINS.find((d) => d.slug === slug);
  if (!domain || domain.implemented) notFound();

  return (
    <div className="max-w-2xl">
      <h1 className="text-2xl font-semibold">{domain.title}</h1>
      <p className="mt-1 text-sm text-stone-500">{domain.description}</p>
      <div className="mt-6 rounded-xl border border-dashed border-stone-300 bg-white p-8 text-center">
        <p className="text-stone-500">
          This domain activates in <span className="font-medium">{domain.milestone}</span>.
        </p>
      </div>
    </div>
  );
}
