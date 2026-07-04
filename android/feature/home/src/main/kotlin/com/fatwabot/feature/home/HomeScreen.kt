package com.fatwabot.feature.home

import androidx.compose.foundation.background
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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.fatwabot.core.common.HomeLayout
import com.fatwabot.core.prayer.HijriDateUi
import com.fatwabot.core.prayer.NextPrayerState
import com.fatwabot.core.prayer.PrayerDayUi
import com.fatwabot.core.prayer.PrayerNameUi

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
) {
    val sections = layout?.renderableSections(SUPPORTED_SECTIONS)?.map { it.type }
        ?: FALLBACK_SECTIONS

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        sections.forEach { type ->
            item(key = type) {
                when (type) {
                    "ambient_header" -> AmbientHeader(hero)
                    "prayer_hero" -> hero?.let { PrayerHeroCard(it, formatTime, prayerTitle) }
                    "ask_ai" -> AskSection(askEnabled)
                    "quick_actions" -> {} // arrives with Worship features on Android in M2
                }
            }
        }
    }
}

@Composable
private fun AmbientHeader(hero: HomeHeroContent?) {
    Column {
        Text(
            stringResource(R.string.home_greeting),
            style = MaterialTheme.typography.headlineSmall,
            color = MaterialTheme.colorScheme.onSurface,
        )
        hero?.hijri?.let {
            Text(
                "${it.monthName} ${it.day}، ${it.year} هـ",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun PrayerHeroCard(
    hero: HomeHeroContent,
    formatTime: (Long) -> String,
    prayerTitle: @Composable (PrayerNameUi) -> String,
) {
    Surface(shape = RoundedCornerShape(20.dp)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.linearGradient(
                        listOf(
                            MaterialTheme.colorScheme.primary,
                            MaterialTheme.colorScheme.primary.copy(alpha = 0.85f),
                        ),
                    ),
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
                        color = MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.75f),
                    )
                    Text(
                        prayerTitle(hero.next.next),
                        style = MaterialTheme.typography.headlineLarge,
                        color = MaterialTheme.colorScheme.onPrimary,
                    )
                }
                Text(
                    formatTime(hero.next.nextTime.epochSeconds),
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onPrimary,
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
                                    MaterialTheme.colorScheme.onPrimary.copy(
                                        alpha = if (isNext) 1f else 0.5f,
                                    ),
                                    CircleShape,
                                ),
                        )
                        Text(
                            prayerTitle(name),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onPrimary.copy(
                                alpha = if (isNext) 1f else 0.6f,
                            ),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun AskSection(enabled: Boolean) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            stringResource(R.string.home_ask_title),
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Surface(
            shape = RoundedCornerShape(14.dp),
            color = MaterialTheme.colorScheme.surfaceContainer,
        ) {
            Text(
                stringResource(R.string.home_ask_placeholder),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(14.dp),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            IntentChip(R.string.home_ask_intent_fatwa, Modifier.weight(1f))
            IntentChip(R.string.home_ask_intent_hadith, Modifier.weight(1f))
            IntentChip(R.string.home_ask_intent_general, Modifier.weight(1f))
        }
        if (!enabled) {
            Text(
                stringResource(R.string.home_ask_coming_soon),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.secondary,
            )
        }
        Text(
            stringResource(R.string.home_ask_trust_line),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun IntentChip(textRes: Int, modifier: Modifier = Modifier) {
    Surface(
        shape = CircleShape,
        color = MaterialTheme.colorScheme.primaryContainer,
        modifier = modifier,
    ) {
        Text(
            stringResource(textRes),
            modifier = Modifier.padding(vertical = 8.dp, horizontal = 10.dp),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.primary,
            maxLines = 1,
        )
    }
}
