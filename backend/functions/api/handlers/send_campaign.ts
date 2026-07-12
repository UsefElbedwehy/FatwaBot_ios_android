// POST /admin/v1/campaigns/{key}/send — admin-triggered FCM campaign dispatch
// (docs/features/push-notifications.md). Loads the campaign + its template +
// notification-type default, resolves the push audience, and dispatches through
// the pure `dispatchCampaign` (preference + daily-cap aware). The delivery_log
// records every send/cap/failure, so this is the authoritative audit trail.
import { apiError, json } from "../http.ts";
import { resolveRequired } from "../locale_resolve.ts";
import type { AppContext } from "../types.ts";
import type { AdminContentRepo, AdminContentRow } from "../admin_types.ts";
import type { DeliveryLogRepo, NotificationPrefsRepo } from "../notification_types.ts";
import type { IdentityRepo } from "../identity_types.ts";
import type { PushSender } from "../fcm_sender.ts";
import { dispatchCampaign } from "../notification_dispatch.ts";

export interface SendCampaignDeps {
  adminContent: AdminContentRepo;
  identity: IdentityRepo;
  notificationPrefs: NotificationPrefsRepo;
  deliveryLog: DeliveryLogRepo;
  pushSender?: PushSender;
}

/** Pick a template row for the campaign: prefer the request locale, then Arabic
 * (canonical), then any — variant 'a'. */
function pickTemplate(rows: AdminContentRow[], locale: string): AdminContentRow | undefined {
  const variantA = rows.filter((r) => (r.fields.variant ?? "a") === "a");
  return variantA.find((r) => r.fields.locale === locale) ??
    variantA.find((r) => r.fields.locale === "ar") ??
    variantA[0];
}

export async function handleSendCampaign(
  ctx: AppContext,
  deps: SendCampaignDeps,
  campaignKey: string,
  now: Date = new Date(),
): Promise<Response> {
  if (!deps.pushSender) {
    return apiError(503, "push_unavailable", "FCM sender is not configured (set FCM_SERVICE_ACCOUNT)");
  }

  const campaigns = await deps.adminContent.list(ctx, "notification-campaigns");
  const campaign = campaigns.find((c) => c.fields.key === campaignKey && c.published);
  if (!campaign) return apiError(404, "unknown_campaign", `No published campaign '${campaignKey}'`);

  const templateKey = campaign.fields.template_key as string;
  const templateRows = (await deps.adminContent.list(ctx, "notification-templates"))
    .filter((t) => t.published && t.fields.key === templateKey);
  const template = pickTemplate(templateRows, ctx.locale);
  if (!template) return apiError(404, "unknown_template", `No published template '${templateKey}'`);

  const notificationTypeKey = template.fields.notification_type_key as string;
  const title = resolveRequired(template.fields.title_translations as Record<string, string>, ctx.locale);
  const body = resolveRequired(template.fields.body_translations as Record<string, string>, ctx.locale);

  const typeRow = (await deps.adminContent.list(ctx, "notification-types"))
    .find((r) => r.published && r.fields.key === notificationTypeKey);
  const defaultEnabled = Boolean(typeRow?.fields.default_enabled ?? true);

  const recipients = await deps.identity.listPushTargets(ctx);
  const since = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())); // start of UTC day

  const summary = await dispatchCampaign(
    ctx,
    {
      notificationPrefs: deps.notificationPrefs,
      deliveryLog: deps.deliveryLog,
      clearToken: (userId) => deps.identity.updatePushToken(userId, null),
    },
    {
      campaignKey,
      notificationTypeKey,
      defaultEnabled,
      dailyCapOverride: (campaign.fields.daily_cap_override as number | null) ?? null,
      title,
      body,
    },
    recipients,
    deps.pushSender,
    since,
  );

  return json({ campaign_key: campaignKey, recipients: recipients.length, ...summary });
}
