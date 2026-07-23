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

/** Daily Challenge Glance widget. Reads the app-written snapshot with zero
 * network (mirror of iOS DailyChallengeWidget). */
class DailyChallengeWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: androidx.glance.GlanceId) {
        val snapshot = GamificationWidgetSnapshotAccess.read(context)
        provideContent {
            GlanceTheme {
                DailyChallengeContent(context, snapshot)
            }
        }
    }
}

@Composable
private fun DailyChallengeContent(context: Context, snapshot: GamificationWidgetSnapshot?) {
    val challenge = snapshot?.dailyChallenge
    Column(
        modifier = GlanceModifier.fillMaxSize().padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (challenge != null) {
            Text(challenge.name, style = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.Medium))
            Text(
                "${challenge.progress}/${challenge.target}",
                style = TextStyle(color = ColorProvider(BrandPrimary), fontSize = 24.sp, fontWeight = FontWeight.Bold),
            )
        } else {
            Text(context.getString(R.string.widget_open_app), style = TextStyle(color = ColorProvider(BrandPrimary)))
        }
    }
}

class DailyChallengeWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = DailyChallengeWidget()
}
