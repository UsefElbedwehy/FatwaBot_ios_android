package com.fatwabot.app.navigation

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.foundation.layout.offset
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.CompositionLocalProvider
import com.fatwabot.app.R
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.brandScreenBackground
import com.fatwabot.core.designsystem.neumorphicSurface
import com.fatwabot.feature.fatwasearch.FatwaSearchMode

/** Search-first Home (client mockup, design/homeDesign.jpeg) — parity with iOS
 * SearchHomeScreen: logo, wordmark, rosette divider, three neumorphic intent
 * cards, an embossed search field, and the manhaj tagline. Cards + search open
 * the AI-search flow (M5) — `onOpen` pushes FatwaSearchScreen for the tapped
 * mode; RootScaffold owns the destination state. */
@Composable
fun SearchHome(onOpen: (FatwaSearchMode) -> Unit) {
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens
    val cs = MaterialTheme.colorScheme

    Column(
        modifier = Modifier
            .fillMaxSize()
            .brandScreenBackground(tokens)
            .verticalScroll(rememberScrollState())
            // Horizontal only, matching iOS: the vertical padding pushed the
            // whole stack ~22dp down from where iOS starts it.
            .padding(horizontal = 22.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(48.dp))
        Image(
            painter = painterResource(com.fatwabot.core.designsystem.R.drawable.fatwabot_logo),
            contentDescription = null,
            // 124×174 to match iOS; it was 94×132, which left the mark visibly
            // smaller and the whole stack sitting higher than iOS's.
            modifier = Modifier.width(124.dp).height(174.dp),
            // Tinted like iOS's FatwaMark, which renders the same raster as a
            // template. Untinted, the raster's baked-in maroon sits on a
            // near-black surface in dark mode and all but disappears.
            colorFilter = ColorFilter.tint(cs.primary),
        )
        Text(
            "FATWA",
            fontFamily = FontFamily.Serif,
            fontSize = 28.sp,
            letterSpacing = 3.sp,
            fontWeight = FontWeight.Medium,
            color = cs.onSurfaceVariant,
            modifier = Modifier.padding(top = 8.dp),
        )

        // Rosette divider (arrow-tipped rules + 8-petal flower).
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            // `widthIn` BEFORE `fillMaxWidth`: the other order makes the cap a
            // no-op (fillMaxWidth pins min == max == parent width, and widthIn's
            // max is then coerced back into that), so the rule spanned the whole
            // screen instead of iOS's 234dp.
            modifier = Modifier.widthIn(max = 234.dp).fillMaxWidth().padding(top = 34.dp, bottom = 42.dp),
        ) {
            DividerRule(pointsStart = true, color = cs.primary, modifier = Modifier.weight(1f))
            RosetteMark(size = 18.dp, color = cs.primary)
            DividerRule(pointsStart = false, color = cs.primary, modifier = Modifier.weight(1f))
        }

        // Cards read fatwa · hadith · question from the start edge (matches the
        // RTL mockup where fatwa is on the right).
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            IntentCard(R.string.home_card_fatwa, Modifier.weight(1f), { onOpen(FatwaSearchMode.FATWA) }) {
                // Flipped so the magnifier handle points bottom-left, matching the mockup.
                Icon(Icons.Filled.Search, null, tint = cs.primary, modifier = Modifier.size(21.dp).graphicsLayer(scaleX = -1f))
            }
            IntentCard(R.string.home_card_hadith, Modifier.weight(1f), { onOpen(FatwaSearchMode.HADITH) }) {
                // Filled closed book, matching iOS's `book.fill`. Was
                // AutoMirrored.MenuBook — an *open outlined* book that also
                // flipped horizontally in Arabic, which iOS's never does.
                Icon(Icons.Filled.Book, null, tint = cs.primary, modifier = Modifier.size(21.dp))
            }
            IntentCard(R.string.home_card_question, Modifier.weight(1f), { onOpen(FatwaSearchMode.GENERAL) }) {
                QuestionBubbleIcon(cs.primary, 23.dp)
            }
        }

        Spacer(Modifier.height(30.dp))
        // Search bar — rounded rect with the maroon magnifier cap pinned to the
        // RIGHT in both languages, matching iOS (which pins the row LTR for the
        // same reason: the cap should not swap sides with the app language).
        val searchShape = RoundedCornerShape(18.dp)
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(54.dp)
                    .neumorphicSurface(cornerRadius = 18.dp, isDark = isSystemInDarkTheme())
                    .clip(searchShape)
                    .background(cs.brandCardFill)
                    .clickable { onOpen(FatwaSearchMode.GENERAL) },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.home_search_placeholder),
                    fontSize = 15.sp,
                    color = cs.onSurfaceVariant,
                    modifier = Modifier.weight(1f).padding(horizontal = 18.dp),
                )
                Box(
                    modifier = Modifier.width(60.dp).fillMaxSize().background(cs.primary),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.Filled.Search,
                        contentDescription = null,
                        tint = cs.onPrimary,
                        modifier = Modifier.size(17.dp),
                    )
                }
            }
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(top = 30.dp, start = 12.dp, end = 12.dp),
        ) {
            // `primary` (maroon), not `secondary` (the gold accent) — iOS draws
            // both rosettes in maroon, and the gold one was the odd mark out.
            RosetteMark(size = 15.dp, color = cs.primary)
            Text(
                stringResource(R.string.home_tagline),
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = cs.primary,
                textAlign = TextAlign.Center,
            )
        }
        // iOS closes with a 40pt spacer; without it the tagline sits flush
        // against the bottom bar's clearance.
        Spacer(Modifier.height(40.dp))
    }
}

/**
 * Fill for the neumorphic home cards and the search field.
 *
 * Light mode is deliberately cream-on-cream (`surface` over the `surface` wash) —
 * that's the mockup, and the shadow is what separates the card. In dark, though,
 * `surface` IS the page background ([brandScreenBackground] gradients from it),
 * so a card filled with it is invisible. Cards step up to `surfaceElevated`,
 * which `Theme.kt` maps onto Material's `surfaceContainer` slot (`surface` and
 * `background` are both the token `surface`, so neither works here).
 */
private val androidx.compose.material3.ColorScheme.brandCardFill: Color
    @Composable get() = if (isSystemInDarkTheme()) surfaceContainer else surface

@Composable
private fun IntentCard(titleRes: Int, modifier: Modifier, onClick: () -> Unit, icon: @Composable () -> Unit) {
    val cs = MaterialTheme.colorScheme
    Column(
        modifier = modifier
            // `heightIn`, not a hard `height`: iOS uses a *minimum* so the card
            // grows when a label wraps to a third line or the user is on a large
            // font scale. Fixed at 104 it clipped instead.
            .heightIn(min = 104.dp)
            // Two-sided: warm drop + top-left highlight. In light mode the card
            // fill IS the page colour, so the highlight is the only thing
            // separating them; Material's single grey shadow left them flat.
            .neumorphicSurface(cornerRadius = 24.dp, isDark = isSystemInDarkTheme())
            .clip(RoundedCornerShape(24.dp))
            .background(cs.brandCardFill)
            .clickable(onClick = onClick)
            // Vertical only — the 10dp horizontal inset narrowed the text column
            // relative to iOS.
            .padding(vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        // Fixed-height icon row so all three labels share a baseline: the icons
        // are 21/21/23dp, so without it the question card's label sat lower.
        Box(modifier = Modifier.height(26.dp), contentAlignment = Alignment.Center) { icon() }
        Spacer(Modifier.height(12.dp))
        Text(
            stringResource(titleRes),
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
            color = cs.onSurface,
            textAlign = TextAlign.Center,
        )
    }
}

/** Round chat-bubble outline with a small down-left tail and a centered "?",
 * matching the mockup's question glyph. Mirrors iOS QuestionBubbleIcon. */
@Composable
fun QuestionBubbleIcon(color: Color, size: Dp) {
    Box(Modifier.size(size)) {
        Canvas(Modifier.fillMaxSize()) {
            val w = this.size.width
            val h = this.size.height
            val lw = w * 0.09f
            val dia = w * 0.80f
            val r = dia / 2f
            val cxC = w * 0.56f              // nudge right to leave room for the tail
            val cyC = r + lw / 2f
            val tail = Path().apply {
                moveTo(cxC - r * 0.72f, cyC + r * 0.70f)
                lineTo(cxC - r * 1.02f, h - lw * 0.5f)
                lineTo(cxC - r * 0.30f, cyC + r * 0.95f)
                close()
            }
            drawPath(tail, color)
            drawCircle(color, radius = r, center = Offset(cxC, cyC), style = Stroke(width = lw))
        }
        // "?" centered inside the circle sub-box.
        Box(
            modifier = Modifier
                .size(size * 0.80f)
                .offset(x = size * 0.16f, y = size * 0.045f),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                "?",
                color = color,
                fontWeight = FontWeight.Bold,
                fontSize = (size.value * 0.46f).sp,
                style = TextStyle(platformStyle = PlatformTextStyle(includeFontPadding = false)),
            )
        }
    }
}

/** A thin rule with a small arrowhead at its outer end. */
@Composable
private fun DividerRule(pointsStart: Boolean, color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.height(9.dp)) {
        val midY = size.height / 2f
        // dp, not raw pixels: as a bare `5f` this was 5 *physical* px, so the
        // arrowheads shrank to ~1.7dp on a 3x screen — effectively invisible,
        // and a different size on every device.
        val tip = 5f * density
        // The rule line.
        val lineStart = if (pointsStart) tip * 1.6f else 0f
        val lineEnd = if (pointsStart) size.width else size.width - tip * 1.6f
        drawLine(
            color = color.copy(alpha = 0.6f),
            start = Offset(lineStart, midY),
            end = Offset(lineEnd, midY),
            strokeWidth = 1.4f * density,
        )
        // Arrowhead triangle at the outer end.
        val path = androidx.compose.ui.graphics.Path()
        if (pointsStart) {
            val x = 0f
            path.moveTo(x, midY)
            path.lineTo(x + tip * 1.6f, midY - tip)
            path.lineTo(x + tip * 1.6f, midY + tip)
        } else {
            val x = size.width
            path.moveTo(x, midY)
            path.lineTo(x - tip * 1.6f, midY - tip)
            path.lineTo(x - tip * 1.6f, midY + tip)
        }
        path.close()
        drawPath(path, color)
    }
}

/** Eight-petal geometric rosette (khatam-style flower) — brand motif for the
 * divider and tagline. Mirrors iOS RosetteMark. */
@Composable
fun RosetteMark(size: Dp, color: Color) {
    Canvas(modifier = Modifier.size(size)) {
        val s = this.size.minDimension
        val petalW = s * 0.26f
        val petalH = s * 0.62f
        for (i in 0 until 8) {
            rotate(degrees = i * 45f) {
                drawOval(
                    color = color,
                    topLeft = Offset(center.x - petalW / 2f, center.y - s * 0.2f - petalH / 2f),
                    size = Size(petalW, petalH),
                )
            }
        }
        drawCircle(color = color, radius = s * 0.13f, center = center)
    }
}
