package com.fatwabot.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
import com.fatwabot.core.prayer.PrayerWidgetSnapshot

private val ExpandedCell = DpSize(250.dp, 180.dp)

/**
 * The whole prayer day on one tile — mirror of iOS `PrayerDaySheetWidget`.
 *
 * ## How this differs from [PrayerDayWidget]
 * [PrayerDayWidget] filters `upcoming` to today's civil date, so it shows only
 * prayers and shrinks as the day is consumed. This renders the snapshot's
 * [PrayerWidgetSnapshot.DaySheet]: a fixed six-row sheet including الشروق, plus
 * منتصف الليل and الثلث الأخير. It does not reorder or shorten as the day
 * progresses, which is what makes it scannable at a glance.
 *
 * Falls back to [PrayerDayWidget]'s "open the app" prompt when the snapshot
 * predates day sheets — that happens for one refresh cycle after an update,
 * until the app next writes a snapshot.
 */
class PrayerDaySheetWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(setOf(ExpandedCell))

    override suspend fun provideGlance(context: Context, id: androidx.glance.GlanceId) {
        val snapshot = WidgetSnapshotAccess.read(context)
        provideContent {
            GlanceTheme {
                PrayerDaySheetContent(context, snapshot)
            }
        }
    }
}

@Composable
private fun PrayerDaySheetContent(context: Context, snapshot: PrayerWidgetSnapshot?) {
    val nowSeconds = System.currentTimeMillis() / 1000
    val sheet = snapshot?.sheet(nowSeconds)
    val compact = LocalSize.current.height < ExpandedCell.height

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .brandSurface()
            .opensApp(context, DeepLink.PRAYER)
            .padding(12.dp),
    ) {
        if (snapshot == null || sheet == null) {
            Text(
                context.getString(R.string.widget_open_app),
                style = TextStyle(color = MaroonProvider),
            )
            return@Column
        }

        // Header: city on one side, the Hijri date on the other.
        Row(modifier = GlanceModifier.fillMaxWidth()) {
            Text(
                snapshot.locationName,
                maxLines = 1,
                style = TextStyle(
                    color = MaroonProvider, fontSize = 12.sp, fontWeight = FontWeight.Bold,
                ),
            )
            Spacer(GlanceModifier.defaultWeight())
            Text(
                "${snapshot.hijriDay} ${snapshot.hijriMonthName} ${snapshot.hijriYear}",
                maxLines = 1,
                style = TextStyle(color = MutedProvider, fontSize = 11.sp),
            )
        }
        Spacer(GlanceModifier.height(8.dp))

        // The highlight comes from nextEntry, not from "first time still in the
        // future" — those differ at sunrise, and computing it locally is how the
        // sheet would highlight الشروق as the next prayer.
        val nextPrayer = snapshot.nextEntry(nowSeconds)?.prayer

        // Glance has no grid primitive, so the sheet is two rows of three.
        sheet.times.chunked(3).forEach { row ->
            Row(modifier = GlanceModifier.fillMaxWidth()) {
                row.forEach { item ->
                    TimeCell(
                        label = prayerLabel(context, item.prayer),
                        epochSeconds = item.timeEpochSeconds,
                        isNext = item.prayer == nextPrayer,
                        // Sunrise is not a prayer and must not read as one.
                        isMuted = item.prayer == "sunrise",
                    )
                }
            }
            Spacer(GlanceModifier.height(6.dp))
        }

        if (!compact && sheet.midnightEpochSeconds != null) {
            Row(modifier = GlanceModifier.fillMaxWidth()) {
                TimeCell(
                    label = context.getString(R.string.widget_prayer_midnight),
                    epochSeconds = sheet.midnightEpochSeconds!!,
                    isNext = false,
                    isMuted = true,
                )
                sheet.lastThirdEpochSeconds?.let {
                    TimeCell(
                        label = context.getString(R.string.widget_prayer_last_third),
                        epochSeconds = it,
                        isNext = false,
                        isMuted = true,
                    )
                }
            }
        }
    }
}

@Composable
private fun androidx.glance.layout.RowScope.TimeCell(
    label: String,
    epochSeconds: Long,
    isNext: Boolean,
    isMuted: Boolean,
) {
    Column(
        modifier = GlanceModifier.defaultWeight(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            label,
            maxLines = 1,
            style = TextStyle(
                color = if (isNext) MaroonProvider else MutedProvider,
                fontSize = 11.sp,
                textAlign = TextAlign.Center,
            ),
        )
        Text(
            formatTime(epochSeconds),
            maxLines = 1,
            style = TextStyle(
                color = when {
                    isNext -> MaroonProvider
                    isMuted -> MutedProvider
                    else -> InkProvider
                },
                fontSize = 13.sp,
                fontWeight = if (isNext) FontWeight.Bold else FontWeight.Normal,
                textAlign = TextAlign.Center,
            ),
        )
    }
}

class PrayerDaySheetWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = PrayerDaySheetWidget()
}
