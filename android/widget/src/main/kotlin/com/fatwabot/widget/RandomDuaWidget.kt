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
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider

private val DuaBrandPrimary = Color(0xFF7A2A2A)
private val DuaOnSurface = Color(0xFF2A2118)
private val DuaSecondary = Color(0xFF6B5E52)

/**
 * A rotating short du'a Glance widget (mirror of the iOS RandomDuaWidget). Uses a
 * bundled curated pool; zero network. Rotates on a ~3-hour cadence.
 */
class RandomDuaWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: androidx.glance.GlanceId) {
        provideContent {
            GlanceTheme {
                DuaContent(context)
            }
        }
    }
}

@Composable
private fun DuaContent(context: Context) {
    val dua = widgetDua()
    Column(
        modifier = GlanceModifier.fillMaxSize().padding(14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            context.getString(R.string.widget_dua_title),
            style = TextStyle(color = ColorProvider(DuaBrandPrimary), fontSize = 12.sp, fontWeight = FontWeight.Bold),
        )
        Spacer(GlanceModifier.height(10.dp))
        Text(
            dua.arabic,
            style = TextStyle(
                color = ColorProvider(DuaOnSurface),
                fontSize = 17.sp,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
            ),
        )
        Spacer(GlanceModifier.height(8.dp))
        Text(
            dua.translation,
            style = TextStyle(color = ColorProvider(DuaSecondary), fontSize = 12.sp, textAlign = TextAlign.Center),
        )
        Spacer(GlanceModifier.defaultWeight())
        Text(
            dua.source,
            modifier = GlanceModifier.fillMaxWidth(),
            style = TextStyle(color = ColorProvider(DuaBrandPrimary), fontSize = 11.sp, textAlign = TextAlign.End),
        )
    }
}

class RandomDuaWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = RandomDuaWidget()
}
