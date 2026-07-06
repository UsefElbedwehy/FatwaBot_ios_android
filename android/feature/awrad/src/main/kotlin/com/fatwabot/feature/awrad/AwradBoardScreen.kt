package com.fatwabot.feature.awrad

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Spa
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
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

/** Daily checklist (docs/features/awrad.md screen 1) — mirror of iOS
 * AwradBoardScreen. */
@Composable
fun AwradBoardScreen(
    viewModel: AwradViewModel = hiltViewModel(),
    locale: String = "ar",
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var showCreateSheet by remember { mutableStateOf(false) }
    var showStats by remember { mutableStateOf(false) }

    LaunchedEffect(locale) { viewModel.loadTemplates(locale) }

    Column(modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(8.dp),
            horizontalArrangement = Arrangement.End,
        ) {
            IconButton(onClick = { showStats = true }) {
                Icon(Icons.Filled.BarChart, contentDescription = "إحصائياتي")
            }
            IconButton(onClick = { showCreateSheet = true }) {
                Icon(Icons.Filled.Add, contentDescription = "إضافة ورد")
            }
        }

        if (state.wirds.isEmpty()) {
            EmptyBoard(onAddWird = { showCreateSheet = true })
        } else {
            LazyColumn(modifier = Modifier.fillMaxSize()) {
                items(state.activeWirds) { wird ->
                    WirdRow(wird, viewModel.todayCount(wird.id), onTick = { viewModel.tick(wird.id) })
                }
                item {
                    Button(
                        onClick = { viewModel.markDayComplete() },
                        enabled = !viewModel.isDayCompletedToday(),
                        modifier = Modifier.fillMaxWidth().padding(16.dp),
                    ) {
                        Text("أتممت وردي اليوم")
                    }
                }
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

@Composable
private fun EmptyBoard(onAddWird: () -> Unit) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                Icons.Filled.Spa,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(40.dp),
            )
            Text("لا توجد أوراد بعد", style = MaterialTheme.typography.titleMedium)
            Text(
                "أضف وردك الأول لتبدأ رحلتك اليومية",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.size(12.dp))
            Button(onClick = onAddWird) { Text("إضافة ورد") }
        }
    }
}

@Composable
private fun WirdRow(wird: Wird, todayCount: Int, onTick: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column {
            Text(wird.name, style = MaterialTheme.typography.bodyLarge)
            Text(
                "$todayCount/${wird.target}",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        IconButton(onClick = onTick) {
            Icon(Icons.Filled.Add, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
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
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
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
