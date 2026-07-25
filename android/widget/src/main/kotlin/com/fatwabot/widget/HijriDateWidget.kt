package com.fatwabot.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
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

/** Hijri Date Glance widget (mirror of iOS HijriDateWidget). */
class HijriDateWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: androidx.glance.GlanceId) {
        val snapshot = WidgetSnapshotAccess.read(context)
        provideContent {
            GlanceTheme {
                Column(
                    modifier = GlanceModifier.fillMaxSize().brandSurface().padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    if (snapshot != null) {
                        Text(
                            "${snapshot.hijriDay}",
                            style = TextStyle(
                                color = MaroonProvider,
                                fontSize = 44.sp,
                                fontWeight = FontWeight.Bold,
                            ),
                        )
                        Text(
                            snapshot.hijriMonthName,
                            style = TextStyle(color = InkProvider, fontSize = 16.sp, fontWeight = FontWeight.Medium),
                        )
                        Text(
                            context.getString(R.string.widget_hijri_year, snapshot.hijriYear),
                            style = TextStyle(color = MutedProvider, fontSize = 12.sp),
                        )
                    } else {
                        Text(context.getString(R.string.widget_open_app), style = TextStyle(color = MaroonProvider))
                    }
                }
            }
        }
    }
}

class HijriDateWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = HijriDateWidget()
}
