// Admin API client (ADR-0009: dashboard talks only to /admin/v1 on the backend).
// M0: unauthenticated health probe against the public gateway; admin auth lands in M2.

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL ?? "";

export interface HealthStatus {
  status: "ok";
  version: string;
}

export async function fetchHealth(): Promise<HealthStatus | null> {
  if (!API_BASE) return null; // no backend configured yet (pre-deploy)
  try {
    const res = await fetch(`${API_BASE}/v1/health`, { next: { revalidate: 30 } });
    if (!res.ok) return null;
    return (await res.json()) as HealthStatus;
  } catch {
    return null;
  }
}
