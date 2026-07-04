// HTTP helpers: consistent envelope, errors, and cache headers.

export function json(body: unknown, status = 200, headers: HeadersInit = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", ...headers },
  });
}

export interface ApiErrorBody {
  error: { code: string; message: string };
}

export function apiError(status: number, code: string, message: string): Response {
  return json({ error: { code, message } } satisfies ApiErrorBody, status);
}

export const notFound = () => apiError(404, "not_found", "Resource not found");
export const methodNotAllowed = () => apiError(405, "method_not_allowed", "Method not allowed");

export function internalError(err: unknown): Response {
  console.error("internal_error", err instanceof Error ? err.stack ?? err.message : err);
  return apiError(500, "internal_error", "Internal server error");
}
