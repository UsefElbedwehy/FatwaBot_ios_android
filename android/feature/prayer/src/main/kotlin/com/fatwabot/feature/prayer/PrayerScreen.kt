package com.fatwabot.feature.prayer

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.LocationCity
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.text.font.FontWeight
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.designsystem.BrandSectionHeader
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.brandScreenBackground
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.core.prayer.PrayerDayUi
import com.fatwabot.core.prayer.PrayerNameUi
import java.time.Instant as JavaInstant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable
fun PrayerScreen(viewModel: PrayerViewModel) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { viewModel.start() }

    if (state.needsLocation) {
        CityPicker(onSelect = viewModel::selectCity)
    } else {
        PrayerDayContent(viewModel = viewModel, state = state)
    }
}

@Composable
private fun PrayerDayContent(viewModel: PrayerViewModel, state: PrayerViewModel.UiState) {
    var dayOffset by rememberSaveable { mutableIntStateOf(0) }
    val day = viewModel.day(dayOffset)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = { dayOffset-- }, enabled = dayOffset > -7) {
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                    contentDescription = stringResource(R.string.prayer_previous_day),
                )
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                if (dayOffset == 0 && state.hijri != null) {
                    Text(
                        "${state.hijri.monthName} ${state.hijri.day}، ${state.hijri.year} هـ",
                        style = MaterialTheme.typography.titleMedium,
                    )
                }
                state.location?.let {
                    Text(
                        it.name,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            IconButton(onClick = { dayOffset++ }, enabled = dayOffset < 7) {
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = stringResource(R.string.prayer_next_day),
                )
            }
        }
        day?.let { TimesCard(day = it, highlight = if (dayOffset == 0) state.nextPrayer?.next else null) }
    }
}

@Composable
private fun TimesCard(day: PrayerDayUi, highlight: PrayerNameUi?) {
    Surface(
        shape = RoundedCornerShape(18.dp),
        color = MaterialTheme.colorScheme.surfaceContainer,
    ) {
        Column(modifier = Modifier.padding(8.dp)) {
            day.ordered.forEachIndexed { index, (name, time) ->
                val isNext = name == highlight
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            if (isNext) MaterialTheme.colorScheme.primaryContainer
                            else MaterialTheme.colorScheme.surfaceContainer,
                            RoundedCornerShape(12.dp),
                        )
                        .padding(horizontal = 16.dp, vertical = 14.dp)
                        .semantics(mergeDescendants = true) {},
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        stringResource(name.titleRes()),
                        style = if (isNext) MaterialTheme.typography.titleMedium
                        else MaterialTheme.typography.bodyLarge,
                        color = if (isNext) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        formatTime(time.epochSeconds),
                        style = if (isNext) MaterialTheme.typography.titleMedium
                        else MaterialTheme.typography.bodyLarge,
                        color = if (isNext) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurface,
                    )
                }
                if (index < day.ordered.lastIndex) {
                    HorizontalDivider(modifier = Modifier.padding(horizontal = 8.dp))
                }
            }
        }
    }
}

@Composable
fun CityPicker(onSelect: (ManualCity, String) -> Unit) {
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .brandScreenBackground(tokens)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        item {
            BrandSectionHeader(
                title = "اختر مدينتك",
                icon = Icons.Filled.LocationCity,
                modifier = Modifier.padding(bottom = 6.dp),
            )
        }
        items(ManualCity.bundled) { city ->
            val name = stringResource(city.titleRes())
            BrandCard(modifier = Modifier.clickable { onSelect(city, name) }) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Filled.LocationOn,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(22.dp),
                    )
                    Spacer(Modifier.width(12.dp))
                    Text(
                        name,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
            }
        }
    }
}

fun PrayerNameUi.titleRes(): Int = when (this) {
    PrayerNameUi.FAJR -> R.string.prayer_fajr
    PrayerNameUi.SUNRISE -> R.string.prayer_sunrise
    PrayerNameUi.DHUHR -> R.string.prayer_dhuhr
    PrayerNameUi.ASR -> R.string.prayer_asr
    PrayerNameUi.MAGHRIB -> R.string.prayer_maghrib
    PrayerNameUi.ISHA -> R.string.prayer_isha
}

private fun ManualCity.titleRes(): Int = when (id) {
    "makkah" -> R.string.city_makkah
    "madinah" -> R.string.city_madinah
    "riyadh" -> R.string.city_riyadh
    "cairo" -> R.string.city_cairo
    "dubai" -> R.string.city_dubai
    "istanbul" -> R.string.city_istanbul
    "london" -> R.string.city_london
    "newyork" -> R.string.city_newyork
    "jakarta" -> R.string.city_jakarta
    "kualalumpur" -> R.string.city_kualalumpur
    "karachi" -> R.string.city_karachi
    else -> R.string.city_casablanca
}

fun formatTime(epochSeconds: Long): String =
    DateTimeFormatter.ofPattern("h:mm a")
        .withZone(ZoneId.systemDefault())
        .format(JavaInstant.ofEpochSecond(epochSeconds))
