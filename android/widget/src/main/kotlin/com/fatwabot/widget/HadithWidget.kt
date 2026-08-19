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

private val CompactCell = DpSize(110.dp, 110.dp)
private val ExpandedCell = DpSize(250.dp, 180.dp)

/**
 * Rotating hadith Glance widget — mirror of the iOS `HadithWidget`. Bundled
 * pool, zero network, renders on first launch.
 *
 * Two layouts, like the du'a widget:
 *  - compact (~2x2): the matn alone, as large as it will fit. A header row
 *    would eat a third of the height to say something the content already says.
 *  - expanded: matn, translation and attribution.
 *
 * Attribution is shown at every size that has room for it, which is not merely
 * decorative — an unattributed hadith on a home screen is the exact thing the
 * app's review gate exists to prevent.
 */
class HadithWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(setOf(CompactCell, ExpandedCell))

    override suspend fun provideGlance(context: Context, id: androidx.glance.GlanceId) {
        provideContent {
            GlanceTheme {
                HadithContent(context)
            }
        }
    }
}

@Composable
private fun HadithContent(context: Context) {
    val size = LocalSize.current
    if (size.width < ExpandedCell.width || size.height < ExpandedCell.height) {
        CompactHadith(context)
    } else {
        ExpandedHadith(context)
    }
}

@Composable
private fun CompactHadith(context: Context) {
    val hadith = widgetHadith()
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .brandSurface()
            .opensApp(context, DeepLink.HADITH)
            .padding(horizontal = 10.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            hadith.arabic,
            modifier = GlanceModifier.fillMaxWidth(),
            maxLines = 4,
            style = TextStyle(
                color = InkProvider,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
            ),
        )
        Spacer(GlanceModifier.height(6.dp))
        Text(
            hadith.source,
            modifier = GlanceModifier.fillMaxWidth(),
            maxLines = 1,
            style = TextStyle(color = MutedProvider, fontSize = 10.sp, textAlign = TextAlign.Center),
        )
    }
}

@Composable
private fun ExpandedHadith(context: Context) {
    val hadith = widgetHadith()
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .brandSurface()
            .opensApp(context, DeepLink.HADITH)
            .padding(14.dp),
    ) {
        Text(
            context.getString(R.string.widget_hadith_title),
            modifier = GlanceModifier.fillMaxWidth(),
            style = TextStyle(color = MaroonProvider, fontSize = 12.sp, fontWeight = FontWeight.Bold),
        )
        Spacer(GlanceModifier.height(6.dp))
        Text(
            hadith.arabic,
            modifier = GlanceModifier.fillMaxWidth(),
            maxLines = 4,
            style = TextStyle(
                color = InkProvider,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.End,
            ),
        )
        Spacer(GlanceModifier.height(6.dp))
        Text(
            hadith.translation,
            modifier = GlanceModifier.fillMaxWidth(),
            maxLines = 3,
            style = TextStyle(color = MutedProvider, fontSize = 12.sp),
        )
        Spacer(GlanceModifier.height(6.dp))
        Text(
            hadith.source,
            modifier = GlanceModifier.fillMaxWidth(),
            style = TextStyle(color = MaroonProvider, fontSize = 11.sp, textAlign = TextAlign.End),
        )
    }
}

class HadithWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = HadithWidget()
}
