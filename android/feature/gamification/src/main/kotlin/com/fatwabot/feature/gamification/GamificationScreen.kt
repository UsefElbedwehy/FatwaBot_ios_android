package com.fatwabot.feature.gamification

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.MilitaryTech
import androidx.compose.material.icons.filled.Whatshot
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.designsystem.BrandEmptyState
import com.fatwabot.core.designsystem.BrandSectionHeader
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.LocalReduceMotion
import com.fatwabot.core.designsystem.MotionTokens
import com.fatwabot.core.designsystem.RingProgress
import com.fatwabot.core.designsystem.brandScreenBackground
import com.fatwabot.core.designsystem.motionAnimationSpec

/** Journey tab — mirror of iOS GamificationScreen. Renders server descriptors
 * verbatim (docs/features/gamification.md). */
@Composable
fun GamificationScreen(viewModel: GamificationViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens

    LaunchedEffect(Unit) { viewModel.load() }

    val profile = state.profile
    val isEmpty = profile.streaks.isEmpty() && profile.missions.isEmpty() && profile.badges.isEmpty()
    val headline = profile.streaks.maxByOrNull { it.currentLength }

    Box(modifier = Modifier.fillMaxSize().brandScreenBackground(tokens)) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(22.dp),
        ) {
            state.error?.let { error -> NoticeCard(error) }

            if (headline != null && headline.currentLength > 0) {
                StreakHeroCard(headline)
            }

            if (profile.streaks.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    BrandSectionHeader("السلاسل", icon = Icons.Filled.Whatshot)
                    profile.streaks.forEach { StreakCard(it) }
                }
            }
            if (profile.missions.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    BrandSectionHeader("المهام", icon = Icons.Filled.MilitaryTech)
                    profile.missions.forEach { MissionCard(it) }
                }
            }
            if (profile.badges.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    BrandSectionHeader("الأوسمة", icon = Icons.Filled.EmojiEvents)
                    BadgeGrid(profile.badges)
                }
            }
            if (!state.isLoading && isEmpty && state.error == null) {
                BrandEmptyState(Icons.Filled.LocalFireDepartment, "ابدأ رحلتك — أكمل نشاطًا لرؤية تقدمك هنا")
            }
        }
        if (state.isLoading && isEmpty) {
            CircularProgressIndicator(
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.align(Alignment.Center),
            )
        }
    }
}

@Composable
private fun NoticeCard(error: String) {
    BrandCard {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(Icons.Filled.WifiOff, contentDescription = null, tint = MaterialTheme.colorScheme.secondary)
            Text(error, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun StreakHeroCard(streak: GamificationStreak) {
    val denom = maxOf(streak.longestLength, streak.currentLength, 1)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(
                Brush.linearGradient(
                    listOf(MaterialTheme.colorScheme.primaryContainer, MaterialTheme.colorScheme.surfaceContainer),
                ),
            )
            .padding(20.dp)
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(96.dp)) {
            RingProgress(value = streak.currentLength.toFloat() / denom, strokeWidth = 9.dp, modifier = Modifier.fillMaxSize())
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    "${streak.currentLength}",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.ExtraBold,
                    color = MaterialTheme.colorScheme.primary,
                )
                Icon(Icons.Filled.LocalFireDepartment, contentDescription = null, tint = MaterialTheme.colorScheme.secondary, modifier = Modifier.size(16.dp))
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(streak.name, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
            Text("الأطول: ${streak.longestLength}", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (streak.graceRemaining > 0) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Icon(Icons.Filled.Favorite, contentDescription = null, tint = MaterialTheme.colorScheme.secondary, modifier = Modifier.size(14.dp))
                    Text("سماحية متبقية: ${streak.graceRemaining}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
                }
            }
        }
    }
}

@Composable
private fun StreakCard(streak: GamificationStreak) {
    BrandCard {
        Row(
            modifier = Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Box(
                modifier = Modifier.size(44.dp).clip(RoundedCornerShape(50)).background(MaterialTheme.colorScheme.primaryContainer),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.LocalFireDepartment, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(streak.name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
                if (streak.graceRemaining > 0) {
                    Text("سماحية متبقية: ${streak.graceRemaining}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Column(horizontalAlignment = Alignment.End) {
                Text("${streak.currentLength}", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                Text("الأطول: ${streak.longestLength}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun MissionCard(mission: GamificationMission) {
    val fraction = if (mission.target > 0) (mission.progress.toFloat() / mission.target).coerceIn(0f, 1f) else 0f
    val reduceMotion = LocalReduceMotion.current
    val animatedFraction by animateFloatAsState(
        targetValue = fraction,
        animationSpec = motionAnimationSpec(reduceMotion, MotionTokens.STANDARD_MS),
        label = "missionProgress",
    )
    BrandCard {
        Row(
            modifier = Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Box(contentAlignment = Alignment.Center, modifier = Modifier.size(48.dp)) {
                RingProgress(value = animatedFraction, strokeWidth = 6.dp, modifier = Modifier.fillMaxSize())
                Text(
                    "${(animatedFraction * 100).toInt()}%",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(mission.name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
                Text("${mission.progress}/${mission.target}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun BadgeGrid(badges: List<GamificationBadge>) {
    // A non-scrolling grid embedded in the outer scroll: fixed height rows.
    LazyVerticalGrid(
        columns = GridCells.Adaptive(minSize = 104.dp),
        modifier = Modifier.fillMaxWidth().heightForRows(badges.size),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        userScrollEnabled = false,
    ) {
        items(badges) { badge -> BadgeTile(badge) }
    }
}

/** Give the embedded grid a deterministic height so it lays out inside the
 * parent vertical scroll (LazyVerticalGrid can't measure itself in an
 * unbounded-height scroll otherwise). ~3 columns assumed. */
private fun Modifier.heightForRows(count: Int): Modifier {
    val rows = (count + 2) / 3
    return this.then(Modifier.height((rows * 132).dp))
}

@Composable
private fun BadgeTile(badge: GamificationBadge) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(0.85f)
            .clip(RoundedCornerShape(18.dp))
            .background(MaterialTheme.colorScheme.surfaceContainer)
            .padding(12.dp)
            .semantics(mergeDescendants = true) {
                contentDescription = if (badge.isEarned) "${badge.name}، تم الحصول عليها" else "${badge.name}، لم يتم الحصول عليها بعد"
            },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .clip(RoundedCornerShape(50))
                .background(
                    if (badge.isEarned) MaterialTheme.colorScheme.secondary.copy(alpha = 0.18f)
                    else MaterialTheme.colorScheme.primary.copy(alpha = 0.06f),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                if (badge.isEarned) Icons.Filled.EmojiEvents else Icons.Filled.Lock,
                contentDescription = null,
                tint = if (badge.isEarned) MaterialTheme.colorScheme.secondary else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Spacer(Modifier.height(8.dp))
        Text(
            badge.name,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center,
            maxLines = 2,
            color = if (badge.isEarned) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
