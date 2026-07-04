import type { Metadata } from "next";
import Link from "next/link";
import { NAV_DOMAINS } from "@/lib/nav";
import "./globals.css";

export const metadata: Metadata = {
  title: "Fatwa Bot — Control Center",
  description: "Operational control center for the Fatwa Bot platform",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-stone-100 text-stone-900 antialiased">
        <div className="flex min-h-screen">
          <aside className="w-64 shrink-0 border-e border-stone-200 bg-white">
            <div className="border-b border-stone-200 px-5 py-4">
              <p className="text-lg font-semibold text-[#7A2A2A]">Fatwa Bot</p>
              <p className="text-xs text-stone-500">Control Center</p>
            </div>
            <nav className="p-3">
              <ul className="space-y-1">
                {NAV_DOMAINS.map((domain) => (
                  <li key={domain.slug}>
                    <Link
                      href={`/${domain.slug === "overview" ? "" : domain.slug}`}
                      className="block rounded-lg px-3 py-2 text-sm hover:bg-stone-100"
                      title={domain.description}
                    >
                      {domain.title}
                    </Link>
                  </li>
                ))}
              </ul>
            </nav>
          </aside>
          <main className="flex-1 p-8">{children}</main>
        </div>
      </body>
    </html>
  );
}
