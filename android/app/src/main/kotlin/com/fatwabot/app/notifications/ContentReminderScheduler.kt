package com.fatwabot.app.notifications

import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.content.getSystemService
import com.fatwabot.core.content.AzkarCollection
import com.fatwabot.core.content.ContentReminderPlanner
import com.fatwabot.core.content.ContentReminderPreferences
import com.fatwabot.core.content.ContentService
import com.fatwabot.core.content.ContentSnippet
import com.fatwabot.core.content.HadithCollectionDetail
import com.fatwabot.core.content.PlannedContentReminder
import com.fatwabot.core.prayer.NotificationPlanner
import kotlinx.datetime.Instant
import kotlinx.datetime.TimeZone

/**
 * Registers the pure [ContentReminderPlanner] output with AlarmManager — mirror
 * of the iOS `ContentReminderScheduler`.
 *
 * Lives in `:app` rather than a feature module because it composes two modules
 * that don't know about each other: `:core:content` (the pool) and `:core:prayer`
 * (the notification budget).
 */
class ContentReminderScheduler(
    private val context: Context,
    private val contentService: ContentService,
    private val stringProvider: (String) -> String,
) {
    private val alarmManager = context.getSystemService<AlarmManager>()!!

    fun ensureChannel() {
        val manager = context.getSystemService<NotificationManager>()!!
        // Its own channel, so a user can silence daily reminders without also
        // silencing the adhan — they are very different in urgency.
        val channel = NotificationChannel(
            CHANNEL_ID,
            stringProvider("notif.channel.content"),
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        manager.createNotificationChannel(channel)
    }

    @SuppressLint("ScheduleExactAlarm")
    fun reschedule(
        preferences: ContentReminderPreferences,
        now: Instant,
        timeZone: TimeZone = TimeZone.currentSystemDefault(),
        locale: String,
    ) {
        cancelAll()

        val azkar = azkarSnippets(contentService.azkar(locale), locale)
        val hadith = hadithSnippets(
            contentService.hadithCollections(locale)
                .mapNotNull { contentService.hadithDetail(it.slug, locale) },
            locale,
        )

        // The budget comes from the prayer planner's own constant rather than a
        // second hardcoded 48 — if that reservation ever changes, content
        // reminders shrink with it instead of pushing the total past the cap.
        val plan = ContentReminderPlanner.plan(
            azkar = azkar,
            hadith = hadith,
            preferences = preferences,
            now = now,
            timeZone = timeZone,
            budget = ContentReminderPlanner.remainingBudget(NotificationPlanner.DEFAULT_BUDGET),
        )

        plan.forEach { item ->
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                item.fireEpochSeconds * 1000,
                pendingIntent(item),
            )
        }

        // Persist ids so a later cancelAll() can target them across process restarts.
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putStringSet(KEY_IDS, plan.map { it.id }.toSet())
            .apply()
    }

    private fun cancelAll() {
        val ids = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getStringSet(KEY_IDS, emptySet()).orEmpty()
        ids.forEach { id ->
            alarmManager.cancel(
                PendingIntent.getBroadcast(
                    context, id.hashCode(),
                    Intent(context, ContentReminderAlarmReceiver::class.java),
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
                ) ?: return@forEach,
            )
        }
    }

    private fun pendingIntent(item: PlannedContentReminder): PendingIntent {
        val intent = Intent(context, ContentReminderAlarmReceiver::class.java).apply {
            putExtra(EXTRA_ID, item.id)
            putExtra(EXTRA_TITLE, stringProvider(item.titleKey))
            putExtra(EXTRA_BODY, item.body)
            // Where the tap lands. Carried as the canonical DeepLink host rather
            // than a hand-built URL, so a renamed route can't silently break it.
            putExtra(EXTRA_DEEP_LINK, item.deepLink.host)
        }
        return PendingIntent.getBroadcast(
            context, item.id.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        const val CHANNEL_ID = "content_reminders"
        const val EXTRA_ID = "id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_DEEP_LINK = "deep_link"
        private const val PREFS = "content_reminders"
        private const val KEY_IDS = "scheduled_ids"

        /**
         * Flattens every category's items. Which field is shown follows the app
         * locale: an English reader gets the translation when there is one, and
         * the Arabic falls back in when there isn't.
         */
        fun azkarSnippets(collection: AzkarCollection?, locale: String): List<ContentSnippet> =
            collection?.categories.orEmpty().flatMap { it.items }.mapNotNull { item ->
                preferredText(item.arabicText, item.translation, locale)
                    ?.let { ContentSnippet(item.id, it) }
            }

        fun hadithSnippets(
            details: List<HadithCollectionDetail>,
            locale: String,
        ): List<ContentSnippet> =
            details.flatMap { it.entries }.mapNotNull { entry ->
                preferredText(entry.arabicText, entry.translation, locale)
                    ?.let { ContentSnippet(entry.id, it) }
            }

        fun preferredText(arabic: String, translation: String?, locale: String): String? {
            if (locale.startsWith("en") && !translation.isNullOrBlank()) return translation
            return arabic.trim().ifEmpty { null }
        }
    }
}
