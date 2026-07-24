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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.QuestionAnswer
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
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

/** Search-first Home (client mockup, design/homeDesign.jpeg) — parity with iOS
 * SearchHomeScreen: logo, wordmark, rosette divider, three neumorphic intent
 * cards, an embossed search field, and the manhaj tagline. Cards + search open a
 * "coming soon" dialog (M5 AI search is on hold). */
@Composable
fun SearchHome() {
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens
    val cs = MaterialTheme.colorScheme
    var showComingSoon by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .brandScreenBackground(tokens)
            .verticalScroll(rememberScrollState())
            .padding(22.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(28.dp))
        Image(
            painter = painterResource(R.drawable.fatwabot_logo),
            contentDescription = null,
            modifier = Modifier.width(112.dp).height(158.dp),
        )
        Text(
            "FATWA BOT",
            fontFamily = FontFamily.Serif,
            fontSize = 32.sp,
            letterSpacing = 4.sp,
            fontWeight = FontWeight.SemiBold,
            color = cs.onSurface,
            modifier = Modifier.padding(top = 6.dp),
        )

        // Rosette divider (arrow-tipped rules + 8-petal flower).
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxWidth().widthIn(max = 300.dp).padding(top = 30.dp, bottom = 34.dp),
        ) {
            DividerRule(pointsStart = true, color = cs.primary, modifier = Modifier.weight(1f))
            RosetteMark(size = 22.dp, color = cs.primary)
            DividerRule(pointsStart = false, color = cs.primary, modifier = Modifier.weight(1f))
        }

        // Cards read fatwa · hadith · question from the start edge (matches the
        // RTL mockup where fatwa is on the right).
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp), modifier = Modifier.fillMaxWidth()) {
            IntentCard(R.string.home_card_fatwa, Icons.Filled.Search, Modifier.weight(1f)) { showComingSoon = true }
            IntentCard(R.string.home_card_hadith, Icons.AutoMirrored.Filled.MenuBook, Modifier.weight(1f)) { showComingSoon = true }
            IntentCard(R.string.home_card_question, Icons.Filled.QuestionAnswer, Modifier.weight(1f)) { showComingSoon = true }
        }

        Spacer(Modifier.height(30.dp))
        // Search pill — maroon magnifier cap pinned to the left in both languages.
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(58.dp)
                    .shadow(6.dp, CircleShape)
                    .clip(CircleShape)
                    .background(cs.surface)
                    .clickable { showComingSoon = true },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier.width(68.dp).fillMaxSize().clip(CircleShape).background(cs.primary),
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Filled.Search, contentDescription = null, tint = cs.onPrimary) }
                Text(
                    stringResource(R.string.home_search_placeholder),
                    color = cs.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 18.dp),
                )
            }
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(top = 26.dp, start = 8.dp, end = 8.dp),
        ) {
            RosetteMark(size = 15.dp, color = cs.secondary)
            Text(
                stringResource(R.string.home_tagline),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = cs.primary,
                textAlign = TextAlign.Center,
            )
        }
    }

    if (showComingSoon) {
        AlertDialog(
            onDismissRequest = { showComingSoon = false },
            confirmButton = { TextButton(onClick = { showComingSoon = false }) { Text(stringResource(R.string.common_ok)) } },
            icon = { Icon(Icons.Filled.Star, contentDescription = null, tint = cs.primary) },
            title = { Text(stringResource(R.string.home_coming_soon_title)) },
            text = { Text(stringResource(R.string.home_coming_soon_body)) },
        )
    }
}

@Composable
private fun IntentCard(titleRes: Int, icon: ImageVector, modifier: Modifier, onClick: () -> Unit) {
    val cs = MaterialTheme.colorScheme
    Column(
        modifier = modifier
            .height(120.dp)
            .shadow(7.dp, RoundedCornerShape(26.dp))
            .clip(RoundedCornerShape(26.dp))
            .background(cs.surface)
            .clickable(onClick = onClick)
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(icon, contentDescription = null, tint = cs.primary, modifier = Modifier.size(28.dp))
        Spacer(Modifier.height(14.dp))
        Text(
            stringResource(titleRes),
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Medium,
            color = cs.onSurface,
            textAlign = TextAlign.Center,
        )
    }
}

/** A thin rule with a small arrowhead at its outer end. */
@Composable
private fun DividerRule(pointsStart: Boolean, color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.height(9.dp)) {
        val midY = size.height / 2f
        val tip = 5f
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
