package com.fatwabot.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceModifier
import androidx.glance.layout.size
import androidx.glance.ColorFilter
import androidx.glance.ImageProvider
import androidx.glance.Image
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
import com.fatwabot.core.common.GamificationWidgetSnapshot
import com.fatwabot.core.common.DeepLink

/** Streak Glance widget. Reads the app-written snapshot with zero network
 * (mirror of iOS StreakWidget). Refreshed by the app via updateAll after
 * GamificationViewModel.load() succeeds. */
class StreakWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: androidx.glance.GlanceId) {
        val snapshot = GamificationWidgetSnapshotAccess.read(context)
        provideContent {
            GlanceTheme {
                StreakContent(context, snapshot)
            }
        }
    }
}

@Composable
private fun StreakContent(context: Context, snapshot: GamificationWidgetSnapshot?) {
    val streak = snapshot?.topStreak
    Column(
        modifier = GlanceModifier.fillMaxSize().brandSurface().opensApp(context, DeepLink.JOURNEY).padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (streak != null) {
            Text(streak.name, style = TextStyle(color = InkProvider, fontSize = 12.sp))
            // Flame + count, matching the Journey tab's badge so the widget and
            // the screen it deep-links to are recognisably one thing. The brand
            // mark is omitted at this size: overlaying two images is not
            // something Glance can do without a pre-composed bitmap, and the
            // mark would be ~8dp here — visual noise rather than branding.
            Image(
                provider = ImageProvider(R.drawable.ic_streak_flame),
                contentDescription = null,
                colorFilter = ColorFilter.tint(MaroonProvider),
                modifier = GlanceModifier.size(30.dp),
            )
            Text(
                "${streak.currentLength}",
                style = TextStyle(color = MaroonProvider, fontSize = 30.sp, fontWeight = FontWeight.Bold),
            )
            Text(
                if (streak.graceRemaining > 0) context.getString(R.string.widget_streak_grace, streak.graceRemaining) else context.getString(R.string.widget_streak_best, streak.longestLength),
                style = TextStyle(color = MutedProvider, fontSize = 11.sp),
            )
        } else {
            Text(context.getString(R.string.widget_open_app), style = TextStyle(color = MaroonProvider))
        }
    }
}

class StreakWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = StreakWidget()
}
