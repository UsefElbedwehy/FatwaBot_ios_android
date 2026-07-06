import { NextRequest, NextResponse } from "next/server";
import { ADMIN_SESSION_COOKIE } from "@/lib/session-constants";

/** Gate the M2-live domains (content, audit) behind a session cookie. Real token
 * validation happens on every backend call (ADR-0009); this is a fast redirect
 * so unauthenticated visitors never render an authenticated shell. */
export function proxy(req: NextRequest) {
  const token = req.cookies.get(ADMIN_SESSION_COOKIE)?.value;
  if (!token) {
    const loginUrl = new URL("/login", req.url);
    loginUrl.searchParams.set("next", req.nextUrl.pathname);
    return NextResponse.redirect(loginUrl);
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/content/:path*", "/audit/:path*"],
};
