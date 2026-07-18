// Pure campaign dispatch (docs/features/notification-campaigns.md). Orchestrates
// per-recipient: preference check → daily-cap check → FCM send → delivery log,
// clearing dead tokens. Pure over injected repos + sender, so fully testable.
import { capCheckAllowed, effectiveDailyCap } from "./notification_engine.ts";
import type { DeliveryLogRepo, NotificationPrefsRepo } from "./notification_types.ts";
import type { PushSender } from "./fcm_sender.ts";
import type { AppContext } from "./types.ts";

export interface DispatchCampaign {
  campaignKey: string;
  notificationTypeKey: string;
  defaultEnabled: boolean;
  dailyCapOverride: number | null;
  title: string;
  body: string;
}

export interface DispatchRecipient {
  userId: string;
  token: string;
}

export interface DispatchSummary {
  sent: number;
  failed: number;
  capped: number;
  skipped: number;
}

export interface DispatchDeps {
  notificationPrefs: NotificationPrefsRepo;
  deliveryLog: DeliveryLogRepo;
  /** Clear a dead push token (FCM reported it unregistered). */
  clearToken: (userId: string) => Promise<void>;
}

export async function dispatchCampaign(
  ctx: AppContext,
  deps: DispatchDeps,
  campaign: DispatchCampaign,
  recipients: DispatchRecipient[],
  sender: PushSender,
  since: Date,
): Promise<DispatchSummary> {
  const cap = effectiveDailyCap(campaign.dailyCapOverride);
  const summary: DispatchSummary = { sent: 0, failed: 0, capped: 0, skipped: 0 };

  for (const r of recipients) {
    // Layer 1 — respect the user's per-type preference.
    const prefs = await deps.notificationPrefs.list(ctx, r.userId);
    const override = prefs.find((p) => p.notificationTypeKey === campaign.notificationTypeKey);
    const enabled = override?.enabled ?? campaign.defaultEnabled;
    if (!enabled) {
      summary.skipped++;
      continue;
    }

    // Layer 2 — daily cap (campaign category only).
    const sentToday = await deps.deliveryLog.countSentSince(ctx, r.userId, since);
    if (!capCheckAllowed(sentToday, cap)) {
      await deps.deliveryLog.record(ctx, campaign.campaignKey, r.userId, "capped");
      summary.capped++;
      continue;
    }

    // Layer 3 — send + log.
    const result = await sender.send(r.token, {
      title: campaign.title,
      body: campaign.body,
      data: { campaign_key: campaign.campaignKey },
    });
    if (result.ok) {
      await deps.deliveryLog.record(ctx, campaign.campaignKey, r.userId, "sent");
      summary.sent++;
    } else {
      await deps.deliveryLog.record(ctx, campaign.campaignKey, r.userId, "failed");
      summary.failed++;
      if (result.unregistered) await deps.clearToken(r.userId);
    }
  }

  return summary;
}
