// GET /v1/notification-types, GET/PATCH /v1/me/notification-prefs,
// POST /v1/notifications/{id}/opened (docs/features/notification-campaigns.md).
//
// Campaign *dispatch* (matching a segment, sending via FCM, applying the
// daily cap) is intentionally not built in M3: it needs both real Firebase
// credentials (Q8, not yet available) and an audience-segment query
// capability beyond this milestone's scope. What IS real and tested here:
// the catalog, per-user preferences, the delivery-log schema, the pure
// cap-check logic (notification_engine.ts), and open-tracking — the pieces
// that don't depend on either gap. Templates/campaigns are still fully
// admin-authorable via the generic content CRUD, ready for a dispatch
// handler to consume once FCM is wired up.
import { verifyAccessToken } from "../auth/jwt.ts";
import { apiError, json } from "../http.ts";
import { resolveRequired } from "../locale_resolve.ts";
import type { AppContext } from "../types.ts";
import type { AdminContentRepo } from "../admin_types.ts";
import type { DeliveryLogRepo, NotificationPrefsRepo } from "../notification_types.ts";

interface NotificationDeps {
  adminContent: AdminContentRepo;
  notificationPrefs: NotificationPrefsRepo;
  deliveryLog: DeliveryLogRepo;
  jwtSecret: string;
}

async function requireUser(req: Request, jwtSecret: string): Promise<string | Response> {
  const header = req.headers.get("authorization");
  if (!header?.startsWith("Bearer ")) return apiError(401, "unauthorized", "Valid bearer token required");
  const claims = await verifyAccessToken(header.slice("Bearer ".length), jwtSecret);
  if (!claims) return apiError(401, "unauthorized", "Valid bearer token required");
  return claims.sub;
}

/** GET /v1/notification-types — public catalog read, drives Settings. */
export async function handleListNotificationTypes(
  ctx: AppContext,
  deps: NotificationDeps,
): Promise<Response> {
  const rows = (await deps.adminContent.list(ctx, "notification-types")).filter((r) => r.published);
  const types = rows.map((r) => ({
    key: r.fields.key,
    category: r.fields.category,
    name: resolveRequired(r.fields.name_translations as Record<string, string>, ctx.locale),
    help_text: resolveRequired(r.fields.help_text_translations as Record<string, string>, ctx.locale),
    default_enabled: r.fields.default_enabled,
    offset_configurable: r.fields.offset_configurable,
    delivery_class: r.fields.delivery_class,
  }));
  return json({ types });
}

/** GET /v1/me/notification-prefs — catalog defaults merged with user overrides. */
export async function handleGetNotificationPrefs(
  ctx: AppContext,
  deps: NotificationDeps,
  req: Request,
): Promise<Response> {
  const userOrError = await requireUser(req, deps.jwtSecret);
  if (userOrError instanceof Response) return userOrError;

  const catalog = (await deps.adminContent.list(ctx, "notification-types")).filter((r) => r.published);
  const overrides = new Map(
    (await deps.notificationPrefs.list(ctx, userOrError)).map((p) => [p.notificationTypeKey, p]),
  );

  const prefs = catalog.map((row) => {
    const key = row.fields.key as string;
    const override = overrides.get(key);
    return {
      notification_type_key: key,
      enabled: override?.enabled ?? Boolean(row.fields.default_enabled),
      offset_minutes: override?.offsetMinutes ?? null,
    };
  });
  return json({ prefs });
}

/** PATCH /v1/me/notification-prefs — body: { notification_type_key, enabled?, offset_minutes? } */
export async function handleUpdateNotificationPrefs(
  ctx: AppContext,
  deps: NotificationDeps,
  req: Request,
  body: unknown,
): Promise<Response> {
  const userOrError = await requireUser(req, deps.jwtSecret);
  if (userOrError instanceof Response) return userOrError;

  const b = (body as Record<string, unknown> | null) ?? {};
  if (typeof b.notification_type_key !== "string" || b.notification_type_key.length === 0) {
    return apiError(400, "invalid_body", "notification_type_key is required");
  }
  const catalog = (await deps.adminContent.list(ctx, "notification-types")).filter((r) => r.published);
  const catalogRow = catalog.find((r) => r.fields.key === b.notification_type_key);
  if (!catalogRow) {
    return apiError(
      404,
      "unknown_notification_type",
      `No published notification type '${b.notification_type_key}'`,
    );
  }

  const existing = (await deps.notificationPrefs.list(ctx, userOrError)).find((p) =>
    p.notificationTypeKey === b.notification_type_key
  );
  const enabled = typeof b.enabled === "boolean"
    ? b.enabled
    : existing?.enabled ?? Boolean(catalogRow.fields.default_enabled);
  const offsetMinutes = b.offset_minutes === null || typeof b.offset_minutes === "number"
    ? (b.offset_minutes as number | null)
    : existing?.offsetMinutes ?? null;

  await deps.notificationPrefs.upsert(ctx, userOrError, {
    notificationTypeKey: b.notification_type_key,
    enabled,
    offsetMinutes,
  });
  return json({ notification_type_key: b.notification_type_key, enabled, offset_minutes: offsetMinutes });
}

/** POST /v1/notifications/{id}/opened — client reports a tap. */
export async function handleMarkNotificationOpened(
  ctx: AppContext,
  deps: NotificationDeps,
  deliveryId: string,
): Promise<Response> {
  const marked = await deps.deliveryLog.markOpened(ctx, deliveryId);
  if (!marked) return apiError(404, "not_found", `No delivery ${deliveryId}`);
  return json({ opened: true });
}
