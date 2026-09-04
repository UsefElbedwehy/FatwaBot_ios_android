package com.fatwabot.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.LocalSize
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import com.fatwabot.core.common.DeepLink
import com.fatwabot.core.prayer.HijriWeek
import com.fatwabot.core.prayer.PrayerWidgetSnapshot
import java.time.ZoneId

private val WideCell = DpSize(250.dp, 110.dp)

/**
 * الصلاة والتقويم — the next prayer beside a Hijri week strip. Mirror of iOS
 * `PrayerCalendarWidget`.
 *
 * The two halves come from different sources on purpose: the countdown needs the
 * app-written snapshot, the calendar is pure Hijri arithmetic. On a device that
 * has never had a location the calendar half still renders — a widget that
 * blanks entirely because one panel lacks data is worse than one showing the
 * half it can.
 */
class PrayerCalendarWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(setOf(WideCell))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val snapshot = WidgetSnapshotAccess.read(context)
        provideContent {
            GlanceTheme { PrayerCalendarContent(context, snapshot) }
        }
    }
}

@Composable
private fun PrayerCalendarContent(context: Context, snapshot: PrayerWidgetSnapshot?) {
    val week = HijriWeek.containing()
    val compact = LocalSize.current.width < WideCell.width

    Row(
        modifier = GlanceModifier
            .fillMaxSize()
            .brandSurface()
            .opensApp(context, DeepLink.PRAYER)
            .padding(12.dp),
    ) {
        Column(modifier = GlanceModifier.defaultWeight()) {
            Countdown(context, snapshot, week)
        }
        if (!compact) {
            Column(
                modifier = GlanceModifier.defaultWeight(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                WeekStrip(week)
            }
        }
    }
}

@Composable
private fun Countdown(context: Context, snapshot: PrayerWidgetSnapshot?, week: HijriWeek) {
    val next = snapshot?.nextEntry(System.currentTimeMillis() / 1000)
    if (next != null) {
        Text(
            prayerLabel(context, next.prayer),
            style = TextStyle(color = MaroonProvider, fontSize = 14.sp, fontWeight = FontWeight.Bold),
        )
        Text(
            formatTime(next.timeEpochSeconds, snapshot?.zoneId ?: ZoneId.systemDefault()),
            style = TextStyle(color = MaroonProvider, fontSize = 20.sp, fontWeight = FontWeight.Bold),
        )
        snapshot.locationName.takeIf { it.isNotBlank() }?.let {
            Text(it, maxLines = 1, style = TextStyle(color = MutedProvider, fontSize = 11.sp))
        }
    } else {
        // No snapshot yet — the Hijri date still works, so say something true.
        Text(
            "${week.days.firstOrNull { it.isToday }?.number ?: 0} ${week.monthName}",
            style = TextStyle(color = MaroonProvider, fontSize = 14.sp, fontWeight = FontWeight.Bold),
        )
        Text(
            context.getString(R.string.widget_open_app),
            style = TextStyle(color = MutedProvider, fontSize = 11.sp),
        )
    }
}

@Composable
private fun WeekStrip(week: HijriWeek) {
    Text(
        "${week.monthName} ${week.year}",
        maxLines = 1,
        style = TextStyle(color = MaroonProvider, fontSize = 11.sp, fontWeight = FontWeight.Bold),
    )
    Spacer(GlanceModifier.height(4.dp))
    Row(modifier = GlanceModifier.fillMaxWidth()) {
        week.days.forEach { day ->
            Column(
                modifier = GlanceModifier.defaultWeight(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    day.weekdayLabel,
                    maxLines = 1,
                    style = TextStyle(color = MutedProvider, fontSize = 8.sp, textAlign = TextAlign.Center),
                )
                Text(
                    "${day.number}",
                    maxLines = 1,
                    style = TextStyle(
                        color = if (day.isToday) MaroonProvider else InkProvider,
                        fontSize = 11.sp,
                        fontWeight = if (day.isToday) FontWeight.Bold else FontWeight.Normal,
                        textAlign = TextAlign.Center,
                    ),
                )
            }
        }
    }
}

class PrayerCalendarWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = PrayerCalendarWidget()
}
