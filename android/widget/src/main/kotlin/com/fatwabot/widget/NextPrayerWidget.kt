package com.fatwabot.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.glance.GlanceModifier
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.glance.GlanceTheme
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fatwabot.core.prayer.PrayerWidgetSnapshot
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val BrandPrimary = Color(0xFF7A2A2A)

/**
 * Next Prayer Glance widget. Reads the app-written snapshot with zero network
 * (mirror of iOS NextPrayerWidget). Refreshed by the app via updateAll on
 * location/settings change.
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
        modifier = GlanceModifier.fillMaxSize().padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (next != null) {
            Text(
                prayerLabel(context, next.prayer),
                style = TextStyle(
                    color = ColorProvider(BrandPrimary),
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
            Text(
                formatTime(next.timeEpochSeconds),
                style = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.Medium),
            )
        } else {
            Text(context.getString(R.string.widget_open_app), style = TextStyle(color = ColorProvider(BrandPrimary)))
        }
    }
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

internal fun formatTime(epochSeconds: Long): String =
    DateTimeFormatter.ofPattern("h:mm a")
        .withZone(ZoneId.systemDefault())
        .format(Instant.ofEpochSecond(epochSeconds))

class NextPrayerWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = NextPrayerWidget()
}
