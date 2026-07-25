package com.fatwabot.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
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
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.fatwabot.core.prayer.PrayerWidgetSnapshot
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import com.fatwabot.core.common.DeepLink

/**
 * Full-day prayer schedule Glance widget: lists all of today's prayers and
 * highlights the coming one. Reads the app-written snapshot (zero network).
 */
class PrayerDayWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: androidx.glance.GlanceId) {
        val snapshot = WidgetSnapshotAccess.read(context)
        provideContent {
            GlanceTheme {
                PrayerDayContent(context, snapshot)
            }
        }
    }
}

@Composable
private fun PrayerDayContent(context: Context, snapshot: PrayerWidgetSnapshot?) {
    val nowSeconds = System.currentTimeMillis() / 1000
    val next = snapshot?.nextEntry(nowSeconds)
    val zone = ZoneId.systemDefault()
    val today = LocalDate.now(zone)
    val todays = snapshot?.upcoming
        ?.filter { LocalDate.ofInstant(Instant.ofEpochSecond(it.timeEpochSeconds), zone) == today }
        ?.take(6)
        .orEmpty()

    Column(
        modifier = GlanceModifier.fillMaxSize().brandSurface().opensApp(context, DeepLink.PRAYER).padding(12.dp),
    ) {
        if (snapshot == null || todays.isEmpty()) {
            Text(
                context.getString(R.string.widget_open_app),
                style = TextStyle(color = MaroonProvider),
            )
            return@Column
        }
        Row(modifier = GlanceModifier.fillMaxWidth()) {
            Text(
                snapshot.locationName,
                style = TextStyle(color = MaroonProvider, fontSize = 13.sp, fontWeight = FontWeight.Medium),
            )
            Spacer(GlanceModifier.defaultWeight())
            Text(
                "${snapshot.hijriDay} ${snapshot.hijriMonthName}",
                style = TextStyle(color = MutedProvider, fontSize = 12.sp),
            )
        }
        Spacer(GlanceModifier.height(8.dp))
        todays.forEach { item ->
            val isNext = item.prayer == next?.prayer
            Row(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .padding(horizontal = 10.dp, vertical = 7.dp)
                    .then(if (isNext) GlanceModifier.background(ColorProvider(BrandHighlight)).cornerRadius(10.dp) else GlanceModifier),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    prayerLabel(context, item.prayer),
                    style = TextStyle(
                        color = if (isNext) MaroonProvider else InkProvider,
                        fontSize = 15.sp,
                        fontWeight = if (isNext) FontWeight.Bold else FontWeight.Normal,
                    ),
                )
                Spacer(GlanceModifier.defaultWeight())
                Text(
                    formatTime(item.timeEpochSeconds),
                    style = TextStyle(
                        color = if (isNext) MaroonProvider else InkProvider,
                        fontSize = 15.sp,
                        fontWeight = if (isNext) FontWeight.Bold else FontWeight.Normal,
                    ),
                )
            }
        }
    }
}

class PrayerDayWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = PrayerDayWidget()
}
