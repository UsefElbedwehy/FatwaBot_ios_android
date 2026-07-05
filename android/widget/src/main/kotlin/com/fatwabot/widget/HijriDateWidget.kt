package com.fatwabot.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
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
import androidx.glance.unit.ColorProvider

private val BrandPrimary = Color(0xFF7A2A2A)

/** Hijri Date Glance widget (mirror of iOS HijriDateWidget). */
class HijriDateWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: androidx.glance.GlanceId) {
        val snapshot = WidgetSnapshotAccess.read(context)
        provideContent {
            GlanceTheme {
                Column(
                    modifier = GlanceModifier.fillMaxSize().padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    if (snapshot != null) {
                        Text(
                            "${snapshot.hijriDay}",
                            style = TextStyle(
                                color = ColorProvider(BrandPrimary),
                                fontSize = 40.sp,
                                fontWeight = FontWeight.Bold,
                            ),
                        )
                        Text(snapshot.hijriMonthName, style = TextStyle(fontSize = 16.sp))
                        Text("${snapshot.hijriYear} هـ", style = TextStyle(fontSize = 12.sp))
                    } else {
                        Text("افتح التطبيق", style = TextStyle(color = ColorProvider(BrandPrimary)))
                    }
                }
            }
        }
    }
}

class HijriDateWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = HijriDateWidget()
}
