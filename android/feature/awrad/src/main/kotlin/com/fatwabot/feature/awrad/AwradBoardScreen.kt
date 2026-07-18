package com.fatwabot.feature.awrad

import androidx.compose.animation.core.animateIntAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.AutoStories
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.outlined.WorkspacePremium
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.invisibleToUser
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.designsystem.BrandSectionHeader
import com.fatwabot.core.designsystem.ColorTokens
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.LocalReduceMotion
import com.fatwabot.core.designsystem.MotionTokens
import com.fatwabot.core.designsystem.RingProgress
import com.fatwabot.core.designsystem.brandScreenBackground
import com.fatwabot.core.designsystem.motionAnimationSpec

/** Daily checklist (docs/features/awrad.md screen 1) — mirror of iOS
 * AwradBoardScreen. */
@Composable
fun AwradBoardScreen(
    viewModel: AwradViewModel = hiltViewModel(),
    locale: String = "ar",
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens
    var showCreateSheet by remember { mutableStateOf(false) }
    var showStats by remember { mutableStateOf(false) }

    LaunchedEffect(locale) { viewModel.loadTemplates(locale) }

    Box(modifier = Modifier.fillMaxSize().brandScreenBackground(tokens)) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(22.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = { showStats = true }) {
                    Icon(Icons.Filled.BarChart, contentDescription = "إحصائياتي", tint = tokens.primary)
                }
                IconButton(onClick = { showCreateSheet = true }) {
                    Icon(Icons.Filled.Add, contentDescription = "إضافة ورد", tint = tokens.primary)
                }
            }

            if (state.wirds.isEmpty()) {
                EmptyBoard(tokens = tokens, onAddWird = { showCreateSheet = true })
            } else {
                StatsGrid(stats = state.stats, tokens = tokens)

                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    BrandSectionHeader("أورادي", icon = Icons.Filled.Spa, tokens = tokens)
                    state.activeWirds.forEach { wird ->
                        WirdCard(
                            wird = wird,
                            todayCount = viewModel.todayCount(wird.id),
                            tokens = tokens,
                            onTick = { viewModel.tick(wird.id) },
                        )
                    }
                }

                MarkDayCompleteCard(
                    done = viewModel.isDayCompletedToday(),
                    tokens = tokens,
                    onComplete = { viewModel.markDayComplete() },
                )
            }
        }
    }

    if (showCreateSheet) {
        AwradCreateDialog(
            viewModel = viewModel,
            onDismiss = { showCreateSheet = false },
        )
    }
    if (showStats) {
        AwradStatsDialog(stats = state.stats, onDismiss = { showStats = false })
    }
}

/** Four premium stat tiles — total dhikr, completed days, quran pages, salawat. */
@Composable
private fun StatsGrid(stats: WirdStats, tokens: ColorTokens) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StatTile("مجموع الأذكار", stats.totalDhikrCount, Icons.Filled.Spa, tokens, Modifier.weight(1f))
            StatTile("أيام مكتملة", stats.completedDaysCount, Icons.Filled.Verified, tokens, Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StatTile("صفحات القرآن", stats.quranPagesCount, Icons.Filled.AutoStories, tokens, Modifier.weight(1f))
            StatTile("الصلاة على النبي", stats.salawatCount, Icons.Filled.Favorite, tokens, Modifier.weight(1f))
        }
    }
}

@Composable
private fun StatTile(
    label: String,
    value: Int,
    icon: ImageVector,
    tokens: ColorTokens,
    modifier: Modifier = Modifier,
) {
    BrandCard(modifier = modifier, tokens = tokens) {
        Column(
            modifier = Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(34.dp)
                    .background(tokens.primaryContainer, RoundedCornerShape(50)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(icon, contentDescription = null, tint = tokens.primary, modifier = Modifier.size(18.dp))
            }
            Text(
                "$value",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.ExtraBold,
                color = tokens.onSurface,
            )
            Text(label, style = MaterialTheme.typography.bodySmall, color = tokens.onSurfaceSecondary)
        }
    }
}

@Composable
private fun EmptyBoard(tokens: ColorTokens, onAddWird: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(top = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Icon(
            Icons.Filled.Spa,
            contentDescription = null,
            tint = tokens.primary,
            modifier = Modifier.size(40.dp).semantics { invisibleToUser() },
        )
        Text(
            "لا توجد أوراد بعد",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = tokens.onSurface,
        )
        Text(
            "أضف وردك الأول لتبدأ رحلتك اليومية",
            style = MaterialTheme.typography.bodyMedium,
            color = tokens.onSurfaceSecondary,
            textAlign = TextAlign.Center,
        )
        Button(onClick = onAddWird) { Text("إضافة ورد") }
    }
}

@Composable
private fun WirdCard(wird: Wird, todayCount: Int, tokens: ColorTokens, onTick: () -> Unit) {
    val reduceMotion = LocalReduceMotion.current
    val animatedCount by animateIntAsState(
        targetValue = todayCount,
        animationSpec = motionAnimationSpec(reduceMotion, MotionTokens.QUICK_MS),
        label = "wirdCount",
    )
    val fraction = if (wird.target > 0) animatedCount.toFloat() / wird.target else 0f
    val reached = todayCount >= wird.target

    BrandCard(tokens = tokens) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Box(contentAlignment = Alignment.Center, modifier = Modifier.size(52.dp)) {
                RingProgress(value = fraction, strokeWidth = 6.dp, modifier = Modifier.fillMaxSize())
                if (reached) {
                    Icon(Icons.Filled.Check, contentDescription = null, tint = tokens.accent, modifier = Modifier.size(22.dp))
                } else {
                    Text(
                        "$animatedCount",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = tokens.primary,
                    )
                }
            }
            Column(modifier = Modifier.weight(1f).semantics(mergeDescendants = true) {}) {
                Text(
                    wird.name,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = tokens.onSurface,
                )
                Text(
                    "$animatedCount/${wird.target}",
                    style = MaterialTheme.typography.labelMedium,
                    color = tokens.onSurfaceSecondary,
                )
            }
            IconButton(onClick = onTick) {
                Icon(Icons.Filled.AddCircle, contentDescription = wird.name, tint = tokens.primary, modifier = Modifier.size(32.dp))
            }
        }
    }
}

@Composable
private fun MarkDayCompleteCard(done: Boolean, tokens: ColorTokens, onComplete: () -> Unit) {
    val alpha = if (done) 0.55f else 1f
    Surface(
        color = Color.Transparent,
        shape = RoundedCornerShape(20.dp),
        onClick = onComplete,
        enabled = !done,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.horizontalGradient(listOf(tokens.primary.copy(alpha = alpha), tokens.accent.copy(alpha = alpha))),
                    RoundedCornerShape(20.dp),
                )
                .padding(horizontal = 18.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(
                if (done) Icons.Filled.Verified else Icons.Outlined.WorkspacePremium,
                contentDescription = null,
                tint = Color.White,
            )
            Text(
                "أتممت وردي اليوم",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.SemiBold,
                color = Color.White,
            )
        }
    }
}

@Composable
private fun AwradStatsDialog(stats: WirdStats, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text("تم") } },
        title = { Text("إحصائياتي") },
        text = {
            Column {
                statRow("مجموع الأذكار", stats.totalDhikrCount)
                statRow("أيام مكتملة", stats.completedDaysCount)
                statRow("صفحات القرآن", stats.quranPagesCount)
                statRow("الصلاة على النبي", stats.salawatCount)
            }
        },
    )
}

@Composable
private fun statRow(label: String, value: Int) {
    Row(
        modifier = Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label)
        Text("$value", color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun AwradCreateDialog(viewModel: AwradViewModel, onDismiss: () -> Unit) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var showCustomForm by remember { mutableStateOf(false) }
    var customName by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("ورد جديد") },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text("إلغاء") } },
        text = {
            Column {
                Text("اختر من القوالب", style = MaterialTheme.typography.labelLarge)
                state.templates.forEach { template ->
                    Surface(
                        onClick = {
                            viewModel.createWird(template)
                            onDismiss()
                        },
                        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                    ) {
                        Column(modifier = Modifier.padding(8.dp)) {
                            Text(template.name)
                            Text(
                                template.description,
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
                if (showCustomForm) {
                    androidx.compose.material3.OutlinedTextField(
                        value = customName,
                        onValueChange = { customName = it },
                        placeholder = { Text("اسم الورد") },
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                    )
                    Button(
                        onClick = {
                            viewModel.createCustomWird(
                                name = customName.ifEmpty { "ورد مخصص" },
                                type = "custom",
                                target = 1,
                                unit = "times",
                                frequency = "daily",
                            )
                            onDismiss()
                        },
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                    ) { Text("حفظ الورد") }
                } else {
                    OutlinedButton(
                        onClick = { showCustomForm = true },
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                    ) { Text("إنشاء ورد مخصص") }
                }
            }
        },
    )
}
