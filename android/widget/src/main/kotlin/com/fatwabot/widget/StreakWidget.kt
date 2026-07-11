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
import com.fatwabot.core.common.GamificationWidgetSnapshot

private val BrandPrimary = Color(0xFF7A2A2A)

/** Streak Glance widget. Reads the app-written snapshot with zero network
 * (mirror of iOS StreakWidget). Refreshed by the app via updateAll after
 * GamificationViewModel.load() succeeds. */
class StreakWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: androidx.glance.GlanceId) {
        val snapshot = GamificationWidgetSnapshotAccess.read(context)
        provideContent {
            GlanceTheme {
                StreakContent(snapshot)
            }
        }
    }
}

@Composable
private fun StreakContent(snapshot: GamificationWidgetSnapshot?) {
    val streak = snapshot?.topStreak
    Column(
        modifier = GlanceModifier.fillMaxSize().padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (streak != null) {
            Text(streak.name, style = TextStyle(fontSize = 12.sp))
            Text(
                "${streak.currentLength}",
                style = TextStyle(color = ColorProvider(BrandPrimary), fontSize = 32.sp, fontWeight = FontWeight.Bold),
            )
            Text(
                if (streak.graceRemaining > 0) "متبقٍ ${streak.graceRemaining} يوم رحمة" else "الأفضل: ${streak.longestLength}",
                style = TextStyle(fontSize = 11.sp),
            )
        } else {
            Text("افتح التطبيق", style = TextStyle(color = ColorProvider(BrandPrimary)))
        }
    }
}

class StreakWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = StreakWidget()
}
