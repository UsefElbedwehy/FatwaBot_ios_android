import bcrypt from "npm:bcryptjs@2";
import { signAdminToken, verifyAdminToken } from "../auth/jwt.ts";
import { apiError, json } from "../http.ts";
import type { AppContext } from "../types.ts";
import type { AdminAuthRepo } from "../admin_types.ts";

function isValidLogin(body: unknown): body is { email: string; password: string } {
  if (typeof body !== "object" || body === null) return false;
  const b = body as Record<string, unknown>;
  return typeof b.email === "string" && b.email.length > 0 && typeof b.password === "string" &&
    b.password.length > 0;
}

/** POST /admin/v1/auth/login */
export async function handleAdminLogin(
  ctx: AppContext,
  repo: AdminAuthRepo,
  jwtSecret: string,
  body: unknown,
): Promise<Response> {
  if (!isValidLogin(body)) {
    return apiError(400, "invalid_credentials", "email and password are required");
  }
  const admin = await repo.findAdminByEmail(ctx, body.email.toLowerCase().trim());
  if (!admin || !(await bcrypt.compare(body.password, admin.passwordHash))) {
    return apiError(401, "invalid_credentials", "Email or password is incorrect");
  }
  const accessToken = await signAdminToken(admin.id, jwtSecret);
  return json({ admin_id: admin.id, access_token: accessToken, expires_in: 60 * 60 });
}

/** Bearer-token guard for every other /admin/v1/* route. Returns the admin id
 * on success, or a 401 Response to short-circuit the caller. */
export async function requireAdmin(req: Request, jwtSecret: string): Promise<string | Response> {
  const header = req.headers.get("authorization");
  if (!header?.startsWith("Bearer ")) {
    return apiError(401, "unauthorized", "Admin bearer token required");
  }
  const claims = await verifyAdminToken(header.slice("Bearer ".length), jwtSecret);
  if (!claims) return apiError(401, "unauthorized", "Invalid or expired admin token");
  return claims.adminId;
}
