package com.fatwabot.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.LocalSize
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
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
import com.fatwabot.core.common.DeepLink

private val SmallCell = DpSize(110.dp, 110.dp)
private val LargeCell = DpSize(250.dp, 180.dp)

/**
 * Rotating du'a / dhikr Glance widget (mirror of the iOS RandomDuaWidget). Uses
 * bundled curated pools; zero network.
 *
 * Two layouts, chosen by the cell the user placed it in:
 *  - compact (~2x2): one *short, complete* dhikr from [widgetShortDhikrPool],
 *    hourly rotation, rendered as large as it will fit with no header row —
 *    a static "Du'a" caption would eat a third of the height and say nothing.
 *  - expanded: the longer du'a pool with translation and source, 3-hour rotation.
 */
class RandomDuaWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(setOf(SmallCell, LargeCell))

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
    val size = LocalSize.current
    if (size.width < LargeCell.width || size.height < LargeCell.height) {
        CompactDhikr(context)
    } else {
        ExpandedDua(context)
    }
}

/** The dhikr gets the whole widget: big, centred, never clipped mid-phrase. */
@Composable
private fun CompactDhikr(context: Context) {
    val dhikr = widgetShortDhikr()
    Column(
        modifier = GlanceModifier.fillMaxSize().brandSurface().opensApp(context, DeepLink.DUA).padding(horizontal = 10.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            dhikr.arabic,
            modifier = GlanceModifier.fillMaxWidth(),
            style = TextStyle(
                color = InkProvider,
                fontSize = compactDhikrFontSize(dhikr.arabic).sp,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
            ),
            maxLines = 2,
        )
    }
}

/**
 * Stand-in for iOS's `minimumScaleFactor` auto-shrink, which Glance/RemoteViews
 * cannot express: size the text from the dhikr's own (diacritic-free) length so
 * every entry in the short pool lands on two lines or fewer.
 */
internal fun compactDhikrFontSize(arabic: String): Int = when (arabicVisualLength(arabic)) {
    in 0..14 -> 30
    in 15..20 -> 26
    in 21..26 -> 23
    else -> 20
}

@Composable
private fun ExpandedDua(context: Context) {
    val dua = widgetDua()
    Column(
        modifier = GlanceModifier.fillMaxSize().brandSurface().opensApp(context, DeepLink.DUA).padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            context.getString(R.string.widget_dua_title),
            style = TextStyle(color = MaroonProvider, fontSize = 12.sp, fontWeight = FontWeight.Bold),
        )
        Spacer(GlanceModifier.height(10.dp))
        Text(
            dua.arabic,
            modifier = GlanceModifier.fillMaxWidth(),
            style = TextStyle(
                color = InkProvider,
                fontSize = 21.sp,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
            ),
        )
        Spacer(GlanceModifier.height(10.dp))
        Text(
            dua.translation,
            modifier = GlanceModifier.fillMaxWidth(),
            style = TextStyle(color = MutedProvider, fontSize = 12.sp, textAlign = TextAlign.Center),
            maxLines = 3,
        )
        Spacer(GlanceModifier.defaultWeight())
        Text(
            dua.source,
            modifier = GlanceModifier.fillMaxWidth(),
            style = TextStyle(color = MaroonProvider, fontSize = 11.sp, textAlign = TextAlign.End),
        )
    }
}

class RandomDuaWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = RandomDuaWidget()
}
