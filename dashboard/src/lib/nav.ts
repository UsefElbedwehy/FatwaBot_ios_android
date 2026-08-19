// Domain-based navigation (ADR-0009: operational control center, built for expansion).
// Each domain grows its own sub-pages per milestone; adding a domain = one entry here.

export interface NavDomain {
  slug: string;
  title: string;
  description: string;
  milestone: string; // when this domain becomes functional
  /** True once the domain has real pages (own app/ route), not the M-placeholder. */
  implemented?: boolean;
}

export const NAV_DOMAINS: NavDomain[] = [
  { slug: "overview", title: "Overview", description: "Platform health & activity", milestone: "M0", implemented: true },
  { slug: "configuration", title: "Configuration", description: "Remote config, flags, theme, strings, Home layout", milestone: "M2", implemented: true },
  { slug: "content", title: "Content", description: "Azkar, duas, hadith collections, wird templates, CMS", milestone: "M2", implemented: true },
  { slug: "gamification", title: "Gamification", description: "Streak rules, missions, badges, leaderboards, rewards", milestone: "M3", implemented: true },
  { slug: "notifications", title: "Notifications", description: "Catalog, templates, campaigns, segments", milestone: "M3", implemented: true },
  { slug: "users", title: "Users", description: "Users, roles, moderators", milestone: "M3", implemented: true },
  { slug: "ai", title: "AI", description: "Providers, routing, prompts, knowledge base, safety, costs", milestone: "M5" },
  { slug: "analytics", title: "Analytics", description: "Usage, retention, funnels, campaign performance", milestone: "M4" },
  { slug: "audit", title: "Audit log", description: "Every admin mutation, who/what/before/after", milestone: "M2", implemented: true },
];
