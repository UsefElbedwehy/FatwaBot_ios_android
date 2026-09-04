package com.fatwabot.widget

import android.content.Context
import android.os.SystemClock
import android.widget.RemoteViews
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import com.fatwabot.core.prayer.PrayerWidgetSnapshot
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import com.fatwabot.core.common.DeepLink

/**
 * Next Prayer Glance widget. Reads the app-written snapshot with zero network
 * (mirror of iOS NextPrayerWidget). Shows the three things a glance needs at
 * once — which prayer, at what clock time, and how long is left — rather than
 * spending a line on a static "Next prayer" caption.
 *
 * Refreshed by the app via updateAll on location/settings change, plus the
 * provider's own update period; the countdown itself ticks on its own (see
 * [Countdown]) so it never shows a stale remaining time between updates.
 */
class NextPrayerWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: androidx.glance.GlanceId) {
        val snapshot = WidgetSnapshotAccess.read(context)
        provideContent {
            GlanceTheme {
                NextPrayerContent(context, snapshot)
            }
        }
    }
}

@Composable
private fun NextPrayerContent(context: Context, snapshot: PrayerWidgetSnapshot?) {
    val nowSeconds = System.currentTimeMillis() / 1000
    val next = snapshot?.nextEntry(nowSeconds)

    Column(
        modifier = GlanceModifier.fillMaxSize().brandSurface().opensApp(context, DeepLink.PRAYER).padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (next == null) {
            Text(
                context.getString(R.string.widget_open_app),
                style = TextStyle(color = MaroonProvider, textAlign = TextAlign.Center),
            )
            return@Column
        }
        Text(
            prayerLabel(context, next.prayer),
            style = TextStyle(
                color = MaroonProvider,
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            ),
        )
        Spacer(GlanceModifier.height(2.dp))
        Text(
            formatTime(next.timeEpochSeconds, snapshot?.zoneId ?: ZoneId.systemDefault()),
            style = TextStyle(
                color = InkProvider,
                fontSize = 18.sp,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
            ),
        )
        Spacer(GlanceModifier.height(6.dp))
        Countdown(context, next.timeEpochSeconds)
    }
}

/**
 * A live, self-ticking countdown. Glance has no equivalent of SwiftUI's
 * `Text(style: .timer)`, so we drop down to a RemoteViews [android.widget.Chronometer]
 * in count-down mode via [AndroidRemoteViews]: the launcher process ticks it
 * every second without any widget update, which is the only way to avoid a
 * remaining time that is up to half an hour stale (the platform floor for
 * `updatePeriodMillis` is 30 minutes).
 */
@Composable
private fun Countdown(context: Context, targetEpochSeconds: Long) {
    val remainingMillis = (targetEpochSeconds * 1000L) - System.currentTimeMillis()
    val views = RemoteViews(context.packageName, R.layout.widget_countdown).apply {
        setChronometer(
            R.id.widget_countdown,
            SystemClock.elapsedRealtime() + remainingMillis.coerceAtLeast(0L),
            context.getString(R.string.widget_countdown_format),
            true,
        )
        setChronometerCountDown(R.id.widget_countdown, true)
    }
    AndroidRemoteViews(views)
}

internal fun prayerLabel(context: Context, raw: String): String = when (raw) {
    "fajr" -> context.getString(R.string.widget_prayer_fajr)
    "sunrise" -> context.getString(R.string.widget_prayer_sunrise)
    "dhuhr" -> context.getString(R.string.widget_prayer_dhuhr)
    "asr" -> context.getString(R.string.widget_prayer_asr)
    "maghrib" -> context.getString(R.string.widget_prayer_maghrib)
    "isha" -> context.getString(R.string.widget_prayer_isha)
    else -> raw
}

internal fun formatTime(epochSeconds: Long, zone: ZoneId = ZoneId.systemDefault()): String =
    DateTimeFormatter.ofLocalizedTime(java.time.format.FormatStyle.SHORT)
        .withZone(zone)
        .format(Instant.ofEpochSecond(epochSeconds))

/** The zone this snapshot's times should render in — the location they were
 *  computed for, falling back to the device's own timezone if none was
 *  resolved (mirrors [com.fatwabot.feature.prayer.zoneId]). */
internal val PrayerWidgetSnapshot.zoneId: ZoneId
    get() = timeZoneId?.let { runCatching { ZoneId.of(it) }.getOrNull() } ?: ZoneId.systemDefault()

class NextPrayerWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = NextPrayerWidget()
}
