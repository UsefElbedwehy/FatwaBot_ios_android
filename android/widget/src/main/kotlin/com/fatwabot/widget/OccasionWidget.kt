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
import androidx.glance.layout.size
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import com.fatwabot.core.common.DeepLink
import com.fatwabot.core.prayer.IslamicOccasion
import com.fatwabot.core.prayer.IslamicOccasionCalculator
import com.fatwabot.core.prayer.IslamicOccasionCountdown

private val WideCell = DpSize(250.dp, 110.dp)

/**
 * رمضان والعيد — days remaining to Ramadan and the two Eids. Mirror of iOS
 * `OccasionWidget`.
 *
 * Zero network and zero snapshot dependency: pure Umm al-Qura arithmetic, so it
 * renders correctly on a device that has never opened the app and never had a
 * location.
 */
class OccasionWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(setOf(WideCell))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val countdowns = IslamicOccasionCalculator.all()
        provideContent {
            GlanceTheme { OccasionContent(context, countdowns) }
        }
    }
}

@Composable
private fun OccasionContent(context: Context, countdowns: List<IslamicOccasionCountdown>) {
    // Narrow shows only the nearest occasion — three rows at that width is three
    // unreadable rows, and the nearest is the one being waited for.
    val compact = LocalSize.current.width < WideCell.width
    val shown = if (compact) countdowns.take(1) else countdowns

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .brandSurface()
            .opensApp(context, DeepLink.PRAYER)
            .padding(12.dp),
        horizontalAlignment = if (compact) Alignment.CenterHorizontally else Alignment.Start,
        verticalAlignment = if (compact) Alignment.CenterVertically else Alignment.Top,
    ) {
        shown.forEach { item ->
            if (compact) {
                Text(
                    occasionLabel(context, item.occasion),
                    style = TextStyle(
                        color = MaroonProvider, fontSize = 14.sp, fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center,
                    ),
                )
                Text(
                    "${item.daysRemaining}",
                    style = TextStyle(
                        color = MaroonProvider, fontSize = 34.sp, fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center,
                    ),
                )
                Text(
                    context.getString(R.string.widget_occasion_days),
                    style = TextStyle(color = MutedProvider, fontSize = 11.sp),
                )
            } else {
                Row(modifier = GlanceModifier.fillMaxWidth()) {
                    Text(
                        occasionLabel(context, item.occasion),
                        style = TextStyle(color = InkProvider, fontSize = 13.sp),
                    )
                    Spacer(GlanceModifier.defaultWeight())
                    Text(
                        "${item.daysRemaining}",
                        style = TextStyle(
                            color = MaroonProvider, fontSize = 16.sp, fontWeight = FontWeight.Bold,
                        ),
                    )
                    Spacer(GlanceModifier.size(4.dp))
                    Text(
                        context.getString(R.string.widget_occasion_days),
                        style = TextStyle(color = MutedProvider, fontSize = 11.sp),
                    )
                }
                Spacer(GlanceModifier.height(8.dp))
            }
        }
    }
}

private fun occasionLabel(context: Context, occasion: IslamicOccasion): String = when (occasion) {
    IslamicOccasion.RAMADAN -> context.getString(R.string.widget_occasion_ramadan)
    IslamicOccasion.EID_AL_FITR -> context.getString(R.string.widget_occasion_eid_al_fitr)
    IslamicOccasion.EID_AL_ADHA -> context.getString(R.string.widget_occasion_eid_al_adha)
}

class OccasionWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = OccasionWidget()
}
