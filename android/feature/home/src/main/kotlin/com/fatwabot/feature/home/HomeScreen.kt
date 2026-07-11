package com.fatwabot.feature.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.QuestionAnswer
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.fatwabot.core.common.HomeLayout
import com.fatwabot.core.designsystem.ColorTokens
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.brandScreenBackground
import com.fatwabot.core.prayer.HijriDateUi
import com.fatwabot.core.prayer.NextPrayerState
import com.fatwabot.core.prayer.PrayerDayUi
import com.fatwabot.core.prayer.PrayerNameUi

/** Home's quick-actions row — mirror of iOS HomeFeature.QuickAction. */
enum class QuickAction(val titleRes: Int, val icon: ImageVector) {
    QIBLA(R.string.quick_qibla, Icons.Filled.Explore),
    TASBEEH(R.string.quick_tasbeeh, Icons.Filled.Circle),
    AZKAR(R.string.quick_azkar, Icons.Filled.MenuBook),
    HISTORY(R.string.quick_history, Icons.Filled.History),
}

/** Prayer state handed in by the app composition (feature→feature forbidden). */
data class HomeHeroContent(
    val next: NextPrayerState,
    val today: PrayerDayUi,
    val hijri: HijriDateUi?,
    val locationName: String?,
)

/** Section catalog v1 — must stay in lockstep with iOS HomeViewModel.supportedSections. */
val SUPPORTED_SECTIONS = setOf("ambient_header", "prayer_hero", "ask_ai", "quick_actions")

val FALLBACK_SECTIONS = listOf("ambient_header", "prayer_hero", "ask_ai", "quick_actions")

@Composable
fun HomeScreen(
    layout: HomeLayout?,
    askEnabled: Boolean,
    hero: HomeHeroContent?,
    formatTime: (Long) -> String,
    prayerTitle: @Composable (PrayerNameUi) -> String,
    onQuickAction: (QuickAction) -> Unit = {},
) {
    val sections = layout?.renderableSections(SUPPORTED_SECTIONS)?.map { it.type }
        ?: FALLBACK_SECTIONS
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .brandScreenBackground(tokens),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        sections.forEach { type ->
            item(key = type) {
                when (type) {
                    "ambient_header" -> AmbientHeader(hero, tokens)
                    "prayer_hero" -> hero?.let { PrayerHeroCard(it, formatTime, prayerTitle, tokens) }
                    "ask_ai" -> AskSection(askEnabled, tokens)
                    "quick_actions" -> QuickActionsRow(onQuickAction, tokens)
                }
            }
        }
    }
}

@Composable
private fun QuickActionsRow(onQuickAction: (QuickAction) -> Unit, tokens: ColorTokens) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        QuickAction.entries.forEach { action ->
            Surface(
                shape = RoundedCornerShape(18.dp),
                color = tokens.surfaceElevated,
                modifier = Modifier
                    .weight(1f)
                    .border(1.dp, tokens.outline.copy(alpha = 0.5f), RoundedCornerShape(18.dp))
                    .clickable { onQuickAction(action) },
            ) {
                Column(
                    modifier = Modifier.padding(vertical = 14.dp, horizontal = 4.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .size(46.dp)
                            .clip(CircleShape)
                            .background(tokens.primaryContainer),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(action.icon, contentDescription = null, tint = tokens.primary)
                    }
                    Text(
                        stringResource(action.titleRes),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = tokens.onSurface,
                        maxLines = 1,
                    )
                }
            }
        }
    }
}

@Composable
private fun AmbientHeader(hero: HomeHeroContent?, tokens: ColorTokens) {
    Column {
        Text(
            stringResource(R.string.home_greeting),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = tokens.onSurface,
        )
        hero?.hijri?.let {
            Text(
                "${it.monthName} ${it.day}، ${it.year} هـ",
                style = MaterialTheme.typography.bodySmall,
                color = tokens.onSurfaceSecondary,
            )
        }
    }
}

@Composable
private fun PrayerHeroCard(
    hero: HomeHeroContent,
    formatTime: (Long) -> String,
    prayerTitle: @Composable (PrayerNameUi) -> String,
    tokens: ColorTokens,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(
                Brush.linearGradient(listOf(tokens.primary, tokens.primary.copy(alpha = 0.85f))),
            )
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column {
                Text(
                    stringResource(R.string.home_next_prayer),
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White.copy(alpha = 0.75f),
                )
                Text(
                    prayerTitle(hero.next.next),
                    style = MaterialTheme.typography.headlineLarge,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                )
            }
            Text(
                formatTime(hero.next.nextTime.epochSeconds),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = Color.White,
            )
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            hero.today.ordered.filter { it.first.isPrayer }.forEach { (name, _) ->
                val isNext = name == hero.next.next
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .size(if (isNext) 8.dp else 5.dp)
                            .background(
                                Color.White.copy(alpha = if (isNext) 1f else 0.5f),
                                CircleShape,
                            ),
                    )
                    Text(
                        prayerTitle(name),
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White.copy(alpha = if (isNext) 1f else 0.6f),
                    )
                }
            }
        }
    }
}

@Composable
private fun AskSection(enabled: Boolean, tokens: ColorTokens) {
    Surface(
        shape = RoundedCornerShape(20.dp),
        color = tokens.surfaceElevated,
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, tokens.outline.copy(alpha = 0.6f), RoundedCornerShape(20.dp)),
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Filled.AutoAwesome, contentDescription = null, tint = tokens.accent, modifier = Modifier.size(20.dp))
                Text(
                    stringResource(R.string.home_ask_title),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = tokens.onSurface,
                )
            }
            Surface(
                shape = RoundedCornerShape(14.dp),
                color = tokens.surface,
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, tokens.outline.copy(alpha = 0.6f), RoundedCornerShape(14.dp)),
            ) {
                Row(
                    modifier = Modifier.padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Icon(Icons.Filled.Search, contentDescription = null, tint = tokens.onSurfaceSecondary, modifier = Modifier.size(18.dp))
                    Text(
                        stringResource(R.string.home_ask_placeholder),
                        color = tokens.onSurfaceSecondary,
                    )
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                IntentChip(R.string.home_ask_intent_fatwa, Icons.Filled.Search, tokens, Modifier.weight(1f))
                IntentChip(R.string.home_ask_intent_hadith, Icons.Filled.Book, tokens, Modifier.weight(1f))
                IntentChip(R.string.home_ask_intent_general, Icons.Filled.QuestionAnswer, tokens, Modifier.weight(1f))
            }
            if (!enabled) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(Icons.Filled.AutoAwesome, contentDescription = null, tint = tokens.accent, modifier = Modifier.size(14.dp))
                    Text(
                        stringResource(R.string.home_ask_coming_soon),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = tokens.accent,
                    )
                }
            }
            Text(
                stringResource(R.string.home_ask_trust_line),
                style = MaterialTheme.typography.labelSmall,
                color = tokens.onSurfaceSecondary,
            )
        }
    }
}

@Composable
private fun IntentChip(textRes: Int, icon: ImageVector, tokens: ColorTokens, modifier: Modifier = Modifier) {
    Surface(
        shape = CircleShape,
        color = tokens.primaryContainer,
        modifier = modifier,
    ) {
        Row(
            modifier = Modifier.padding(vertical = 8.dp, horizontal = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Icon(icon, contentDescription = null, tint = tokens.primary, modifier = Modifier.size(14.dp))
            Text(
                stringResource(textRes),
                style = MaterialTheme.typography.labelMedium,
                color = tokens.primary,
                maxLines = 1,
            )
        }
    }
}
