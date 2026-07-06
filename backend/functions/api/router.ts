// Pure router: no Deno/Supabase globals so it is unit-testable.
// The gateway function is served at /functions/v1/api on Supabase; clients call
// paths like /functions/v1/api/v1/health (mobile) or
// /functions/v1/api/admin/v1/... (dashboard, ADR-0009). Routing happens on the
// "/v1/..." or "/admin/v1/..." suffix.

import { apiError, internalError, json, methodNotAllowed, notFound } from "./http.ts";
import { resolveContext } from "./context.ts";
import { verifyAccessToken } from "./auth/jwt.ts";
import type { ConfigRepo } from "./types.ts";
import type { IdentityRepo } from "./identity_types.ts";
import type { ContentRepo } from "./content_types.ts";
import type { AdminAuthRepo, AdminContentRepo, AuditLogRepo } from "./admin_types.ts";
import type { IdentityProviderVerifier, ProviderKind } from "./auth/provider_verify.ts";
import type { GamificationRepo } from "./gamification_types.ts";
import { handleAnonymousAuth, handleRefresh } from "./handlers/auth.ts";
import { handleLinkProvider, handleProviderSignIn, handleUpdateProfile } from "./handlers/accounts.ts";
import { handleGamificationProfile, handleSubmitEvents } from "./handlers/gamification.ts";
import {
  handleConfig,
  handleHomeLayout,
  handlePrayerDefaults,
  handleStringPack,
  handleTheme,
} from "./handlers/config.ts";
import {
  handleAzkarCollection,
  handleDuaCollection,
  handleHadithCollectionDetail,
  handleHadithCollections,
  handleWirdTemplates,
} from "./handlers/content.ts";
import { handleAdminLogin, requireAdmin } from "./handlers/admin_auth.ts";
import {
  handleCreateContent,
  handleListAuditLog,
  handleListContent,
  handleSetPublished,
  handleUpdateContent,
} from "./handlers/admin_content.ts";

export interface Deps {
  repo: ConfigRepo;
  identity: IdentityRepo;
  content: ContentRepo;
  adminContent: AdminContentRepo;
  adminAuth: AdminAuthRepo;
  auditLog: AuditLogRepo;
  jwtSecret: string;
  verifier: IdentityProviderVerifier;
  gamification: GamificationRepo;
}

/** Extracts the API path suffix beginning at "/v1/..." or "/admin/v1/...".
 *  The Supabase function mount lives under "/functions/v1/api/", so we
 *  locate that marker and keep everything after it; bare-mounted forms
 *  (local testing) are matched by an explicit prefix check. */
export function apiPath(pathname: string): string | null {
  const marker = "/api/";
  const idx = pathname.indexOf(marker);
  if (idx !== -1) return pathname.slice(idx + marker.length - 1);
  if (pathname.startsWith("/v1/") || pathname.startsWith("/admin/v1/")) return pathname;
  return null;
}

async function readBody(req: Request): Promise<unknown | undefined> {
  try {
    return await req.json();
  } catch {
    return undefined;
  }
}

export async function route(req: Request, deps: Deps): Promise<Response> {
  const url = new URL(req.url);
  const path = apiPath(url.pathname);
  if (path === null) return notFound();

  const ctx = resolveContext(req);
  const method = req.method;
  try {
    if (path.startsWith("/admin/v1/")) {
      return await routeAdmin(req, deps, ctx, method, path, url);
    }

    // --- public reads ---
    if (method === "GET") {
      switch (path) {
        case "/v1/health":
          return json({ status: "ok", version: "v1" });
        case "/v1/config":
          return await handleConfig(ctx, deps.repo);
        case "/v1/config/theme":
          return await handleTheme(ctx, deps.repo);
        case "/v1/home":
          return await handleHomeLayout(ctx, deps.repo);
        case "/v1/config/prayer-defaults":
          return await handlePrayerDefaults(ctx, deps.repo, url.searchParams.get("country") ?? "*");
        case "/v1/content/azkar":
          return await handleAzkarCollection(ctx, deps.content, url.searchParams.get("since_version"));
        case "/v1/content/duas":
          return await handleDuaCollection(ctx, deps.content, url.searchParams.get("since_version"));
        case "/v1/content/hadith-collections":
          return await handleHadithCollections(ctx, deps.content);
        case "/v1/content/wird-templates":
          return await handleWirdTemplates(ctx, deps.content, url.searchParams.get("since_version"));
      }
      const stringsMatch = path.match(/^\/v1\/config\/strings\/([A-Za-z0-9-]{2,20})$/);
      if (stringsMatch) {
        const since = url.searchParams.get("since_version");
        return await handleStringPack(ctx, deps.repo, stringsMatch[1], since ? Number(since) : null);
      }
      const hadithDetailMatch = path.match(/^\/v1\/content\/hadith-collections\/([A-Za-z0-9_-]{1,40})$/);
      if (hadithDetailMatch) {
        const since = url.searchParams.get("since_version");
        return await handleHadithCollectionDetail(ctx, deps.content, hadithDetailMatch[1], since);
      }
      // --- authenticated reads ---
      if (path === "/v1/me") {
        const claims = await authenticate(req, deps.jwtSecret);
        if (!claims) return apiError(401, "unauthorized", "Valid bearer token required");
        const profile = await deps.identity.getProfile(claims.sub);
        return json({
          user_id: claims.sub,
          kind: claims.kind,
          display_name: profile?.displayName ?? null,
          provider: profile?.provider ?? "anonymous",
        });
      }
      if (path === "/v1/gamification/profile") {
        return await handleGamificationProfile(ctx, deps, req, url.searchParams.get("timezone"));
      }
      return notFound();
    }

    // --- auth writes ---
    if (method === "POST") {
      switch (path) {
        case "/v1/auth/anonymous":
          return await handleAnonymousAuth(ctx, deps, await readBody(req));
        case "/v1/auth/refresh":
          return await handleRefresh(ctx, deps, await readBody(req));
        case "/v1/auth/apple":
        case "/v1/auth/google":
          return await handleProviderSignIn(
            ctx,
            deps,
            path.slice("/v1/auth/".length) as ProviderKind,
            await readBody(req),
          );
        case "/v1/auth/link":
          return await handleLinkProvider(ctx, deps, req, await readBody(req));
        case "/v1/gamification/events":
          return await handleSubmitEvents(ctx, deps, req, await readBody(req));
      }
      return notFound();
    }

    if (method === "PATCH" && path === "/v1/me/profile") {
      return await handleUpdateProfile(deps, req, await readBody(req));
    }

    return methodNotAllowed();
  } catch (err) {
    return internalError(err);
  }
}

async function authenticate(req: Request, secret: string) {
  const header = req.headers.get("authorization");
  if (!header?.startsWith("Bearer ")) return null;
  return await verifyAccessToken(header.slice("Bearer ".length), secret);
}

const COLLECTION_SEGMENT = "[A-Za-z0-9-]{1,40}";
const ID_SEGMENT = "[A-Za-z0-9-]{1,64}";

/** Admin surface (ADR-0009): every route except login requires a valid admin
 * bearer token. Kept as its own function since PATCH doesn't fit the mobile
 * router's GET/POST-only dispatch above. */
async function routeAdmin(
  req: Request,
  deps: Deps,
  ctx: ReturnType<typeof resolveContext>,
  method: string,
  path: string,
  url: URL,
): Promise<Response> {
  if (method === "POST" && path === "/admin/v1/auth/login") {
    return await handleAdminLogin(ctx, deps.adminAuth, deps.jwtSecret, await readBody(req));
  }

  const adminIdOrError = await requireAdmin(req, deps.jwtSecret);
  if (adminIdOrError instanceof Response) return adminIdOrError;
  const adminId = adminIdOrError;

  if (method === "GET" && path === "/admin/v1/audit-log") {
    return await handleListAuditLog(ctx, deps.auditLog, url.searchParams.get("collection"));
  }

  const listOrCreateMatch = path.match(new RegExp(`^/admin/v1/content/(${COLLECTION_SEGMENT})$`));
  if (listOrCreateMatch) {
    const collection = listOrCreateMatch[1];
    if (method === "GET") return await handleListContent(ctx, deps.adminContent, collection);
    if (method === "POST") {
      return await handleCreateContent(
        ctx,
        deps.adminContent,
        deps.auditLog,
        adminId,
        collection,
        await readBody(req),
      );
    }
    return methodNotAllowed();
  }

  const updateMatch = path.match(new RegExp(`^/admin/v1/content/(${COLLECTION_SEGMENT})/(${ID_SEGMENT})$`));
  if (updateMatch) {
    if (method !== "PATCH") return methodNotAllowed();
    const [, collection, id] = updateMatch;
    return await handleUpdateContent(
      ctx,
      deps.adminContent,
      deps.auditLog,
      adminId,
      collection,
      id,
      await readBody(req),
    );
  }

  const publishMatch = path.match(
    new RegExp(`^/admin/v1/content/(${COLLECTION_SEGMENT})/(${ID_SEGMENT})/(publish|unpublish)$`),
  );
  if (publishMatch) {
    if (method !== "POST") return methodNotAllowed();
    const [, collection, id, action] = publishMatch;
    return await handleSetPublished(
      ctx,
      deps.adminContent,
      deps.auditLog,
      adminId,
      collection,
      id,
      action === "publish",
    );
  }

  return notFound();
}
