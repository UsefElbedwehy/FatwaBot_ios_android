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
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
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
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import com.fatwabot.core.common.WorshipDeed
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

private val LargeCell = DpSize(250.dp, 180.dp)
private val DeedKey = ActionParameters.Key<String>("deed")

/**
 * متابعة العبادات — log a prayer or adhkar with one tap. Mirror of iOS
 * `WorshipTrackerWidget`.
 *
 * No network, by design: the tap writes to `WorshipInbox` and the app uploads on
 * next foreground (ADR-0003). That is why it works offline with no spinner and
 * no failure state.
 */
class WorshipTrackerWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(setOf(LargeCell))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val completed = WorshipTrackerAccess.completedToday(context)
        provideContent {
            GlanceTheme {
                WorshipTrackerContent(context, completed)
            }
        }
    }
}

/** Marks one deed done, then re-renders so the tile fills in immediately — a tap
 *  that registers but shows nothing reads as a broken button. */
class LogWorshipAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        val deed = parameters[DeedKey]?.let { WorshipDeed.fromKey(it) } ?: return
        WorshipTrackerAccess.log(context, deed)
        WorshipTrackerWidget().updateAll(context)
    }
}

@Composable
private fun WorshipTrackerContent(context: Context, completed: Set<String>) {
    val deeds = if (LocalSize.current.height >= LargeCell.height) {
        WorshipDeed.entries.toList()
    } else {
        WorshipDeed.prayers
    }

    Column(
        modifier = GlanceModifier.fillMaxSize().brandSurface().padding(12.dp),
    ) {
        Row(modifier = GlanceModifier.fillMaxWidth()) {
            Text(
                context.getString(R.string.widget_worship_tracker),
                style = TextStyle(
                    color = MaroonProvider, fontSize = 12.sp, fontWeight = FontWeight.Bold,
                ),
            )
            Spacer(GlanceModifier.defaultWeight())
            Text(
                "${deeds.count { completed.contains(it.key) }}/${deeds.size}",
                style = TextStyle(color = MutedProvider, fontSize = 12.sp),
            )
        }
        Spacer(GlanceModifier.height(8.dp))

        // Glance has no grid primitive; rows of three, each claiming an equal
        // share of the height. Without `defaultWeight` the rows stack at the top
        // and leave the bottom of a large tile empty, which reads as broken
        // rather than spacious (the same fix as iOS).
        //
        // Short final rows are padded with empty weighted slots so two tiles are
        // the same width as three; otherwise the last row stretches and the grid
        // stops looking like a grid.
        deeds.chunked(3).forEach { row ->
            Row(modifier = GlanceModifier.fillMaxWidth().defaultWeight()) {
                row.forEach { deed ->
                    DeedTile(context, deed, completed.contains(deed.key))
                }
                repeat(3 - row.size) {
                    Spacer(GlanceModifier.defaultWeight())
                }
            }
        }
    }
}

@Composable
private fun androidx.glance.layout.RowScope.DeedTile(
    context: Context,
    deed: WorshipDeed,
    isDone: Boolean,
) {
    Column(
        modifier = GlanceModifier
            .defaultWeight()
            .padding(2.dp)
            .cornerRadius(8.dp)
            .background(if (isDone) DoneTileProvider else IdleTileProvider)
            .clickable(actionRunCallback<LogWorshipAction>(actionParametersOf(DeedKey to deed.key))),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            if (isDone) "✓" else "",
            style = TextStyle(color = MaroonProvider, fontSize = 12.sp),
        )
        Text(
            deedLabel(context, deed),
            maxLines = 1,
            style = TextStyle(
                color = if (isDone) MaroonProvider else InkProvider,
                fontSize = 11.sp,
                fontWeight = if (isDone) FontWeight.Bold else FontWeight.Normal,
                textAlign = TextAlign.Center,
            ),
        )
    }
}

private fun deedLabel(context: Context, deed: WorshipDeed): String = when (deed) {
    WorshipDeed.AZKAR_MORNING -> context.getString(R.string.widget_deed_azkar_morning)
    WorshipDeed.AZKAR_EVENING -> context.getString(R.string.widget_deed_azkar_evening)
    else -> prayerLabel(context, deed.key)
}

/**
 * Reads and writes the tracker's state.
 *
 * Done-state is the union of the app's `completedToday` and inbox entries not
 * yet drained. Either source alone is wrong in a way the user sees: the snapshot
 * lags behind taps until the app next runs, and the inbox empties the moment it
 * drains — so tiles would flicker back to undone at exactly the moment the deed
 * became durable.
 */
internal object WorshipTrackerAccess {
    fun completedToday(context: Context): Set<String> {
        val recorded = GamificationWidgetSnapshotAccess.read(context)?.completedToday.orEmpty()
        val today = LocalDate.now(ZoneId.systemDefault())
        val pending = com.fatwabot.core.common.WorshipInbox.default(context.filesDir).peek()
            .filter {
                Instant.ofEpochSecond(it.occurredAtEpochSeconds)
                    .atZone(ZoneId.systemDefault()).toLocalDate() == today
            }
            .mapNotNull { entry ->
                entry.metadata["prayer"] ?: entry.metadata["category"]?.let { "azkar_$it" }
            }
        return recorded.toSet() + pending
    }

    fun log(context: Context, deed: WorshipDeed) {
        com.fatwabot.core.common.WorshipInbox.default(context.filesDir).deposit(
            com.fatwabot.core.common.WorshipInboxEntry(
                eventType = deed.eventType,
                occurredAtEpochSeconds = Instant.now().epochSecond,
                metadata = deed.metadata,
            ),
        )
    }
}

class WorshipTrackerWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = WorshipTrackerWidget()
}
