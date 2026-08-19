package com.fatwabot.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.ActionParameters
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import com.fatwabot.core.common.TasbihWidgetCounter

/**
 * العداد — the interactive dhikr counter. Mirror of iOS `TasbihWidget`.
 *
 * The whole tile counts. A small centre button would be the obvious layout and
 * the wrong one: dhikr is repeated without looking, so the target should be
 * everything the thumb can land on. Reset sits in a corner, deliberately small,
 * so it is reachable without being in the path of a thumb tapping the same tile
 * a hundred times.
 */
class TasbihWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val count = TasbihWidgetCounter.store(context.filesDir).read().current()
        provideContent {
            GlanceTheme { TasbihContent(context, count) }
        }
    }
}

class IncrementTasbihAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val store = TasbihWidgetCounter.store(context.filesDir)
        store.write(store.read().incremented())
        TasbihWidget().updateAll(context)
    }
}

class ResetTasbihAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val store = TasbihWidgetCounter.store(context.filesDir)
        store.write(store.read().reset())
        TasbihWidget().updateAll(context)
    }
}

@Composable
private fun TasbihContent(context: Context, count: Int) {
    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .brandSurface()
            .clickable(actionRunCallback<IncrementTasbihAction>()),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                "$count",
                style = TextStyle(
                    color = MaroonProvider,
                    fontSize = 40.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center,
                ),
            )
            Text(
                context.getString(R.string.widget_tasbih_hint),
                style = TextStyle(color = MutedProvider, fontSize = 11.sp),
            )
        }
        Box(
            modifier = GlanceModifier
                .padding(6.dp)
                .clickable(actionRunCallback<ResetTasbihAction>()),
            contentAlignment = Alignment.TopStart,
        ) {
            Text(
                context.getString(R.string.widget_tasbih_reset),
                style = TextStyle(color = MutedProvider, fontSize = 11.sp),
            )
        }
    }
}

class TasbihWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TasbihWidget()
}
