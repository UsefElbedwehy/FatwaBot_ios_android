// Split from session.ts so the Edge middleware can import the cookie name
// without pulling in next/headers (Node-only server API).
export const ADMIN_SESSION_COOKIE = "fatwabot_admin_token";
