package com.fatwabot.app.navigation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import android.app.TimePickerDialog
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.text.format.DateFormat
import java.util.Locale
import androidx.compose.foundation.clickable
import androidx.compose.ui.platform.LocalContext
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.Contrast
import androidx.compose.material.icons.filled.Language
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material.icons.filled.Check
import androidx.core.os.LocaleListCompat
import androidx.appcompat.app.AppCompatDelegate
import com.fatwabot.app.theme.ThemeMode
import com.fatwabot.app.theme.ThemeModeController
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Campaign
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.HelpOutline
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.NightsStay
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.NotificationsNone
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Button
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.fatwabot.app.BuildConfig
import com.fatwabot.app.R
import com.fatwabot.app.account.AccountViewModel
import com.fatwabot.app.notifications.ContentReminderViewModel
import com.fatwabot.app.notifications.WirdReminderViewModel
import com.fatwabot.feature.awrad.FixedWirdSlot
import com.fatwabot.feature.awrad.WirdReminderTime
import com.fatwabot.feature.awrad.fixedWirdNameResolver
import com.fatwabot.core.content.ContentReminderPreferences
import com.fatwabot.feature.awrad.WirdReminderPreferences
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.network.AccountProvider
import kotlinx.coroutines.launch
import com.fatwabot.core.designsystem.BrandSectionHeader
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.InfoNotice
import com.fatwabot.core.designsystem.brandScreenBackground
import com.fatwabot.core.prayer.PrayerNameUi
import com.fatwabot.core.prayer.PrayerNotificationPreferences
import com.fatwabot.feature.prayer.PrayerViewModel
import com.fatwabot.feature.prayer.titleRes

/**
 * Settings tab — profile-first, mirroring iOS SettingsScreen. Adds per-type
 * notification controls (every notification is toggleable; offsets user-set)
 * and a "?" features guide (stakeholder direction, 2026-07-12).
 */
@Composable
fun SettingsScreen(
    prayerViewModel: PrayerViewModel,
    /**
     * Resolved in the composition root (RootScaffold) from the config string
     * packs, so this screen keeps no config/network dependency (ADR-0010).
     */
    contact: ContactLinks,
) {
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens
    Column(
        modifier = Modifier
            .fillMaxSize()
            .brandScreenBackground(tokens)
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(22.dp),
    ) {
        AccountSection()

        AppearanceSection()

        LanguageSection()

        NotificationsSection(prayerViewModel)

        FeaturesGuideSection()

        DiagnosticsSection()

        // Hidden entirely while the dashboard has supplied no channel — an empty
        // "Contact" header helps nobody.
        if (!contact.isEmpty) {
            ContactSection(links = contact)
        }

        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            BrandSectionHeader(stringResource(R.string.settings_about), icon = Icons.Filled.Info)
            BrandCard {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(stringResource(R.string.settings_version), color = MaterialTheme.colorScheme.onSurface)
                    Text(BuildConfig.VERSION_NAME, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

@dagger.hilt.EntryPoint
@dagger.hilt.InstallIn(dagger.hilt.components.SingletonComponent::class)
private interface DiagnosticsEntryPoint {
    fun tracker(): com.fatwabot.app.analytics.FirebaseAnalyticsTracker
    fun analytics(): com.fatwabot.core.common.AnalyticsTracking
}

/** Diagnostics opt-out. Crash + usage reporting is on by default (a crash you
 * can't see is a crash you can't fix, and nothing personal is collected), but
 * this is a worship app — someone who would rather send nothing at all
 * shouldn't have to uninstall to get that. Flipping it disables the SDKs
 * themselves, not just our call sites — and, via the composite, also drops
 * whatever our own ingest still has queued, so nothing recorded before the
 * decision is transmitted after it. */
@Composable
private fun DiagnosticsSection() {
    val context = LocalContext.current
    val entryPoint = remember {
        dagger.hilt.android.EntryPointAccessors
            .fromApplication(context.applicationContext, DiagnosticsEntryPoint::class.java)
    }
    // Concrete tracker for the current choice; the composite to apply a change,
    // so Firebase and our own recorder both hear about it.
    val tracker = remember(entryPoint) { entryPoint.tracker() }
    val analytics = remember(entryPoint) { entryPoint.analytics() }
    var enabled by remember { mutableStateOf(tracker.isCollectionEnabled) }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        BrandSectionHeader(stringResource(R.string.settings_diagnostics), icon = Icons.Filled.Info)
        BrandCard {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        stringResource(R.string.settings_diagnostics_share),
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        stringResource(R.string.settings_diagnostics_note),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Switch(
                    checked = enabled,
                    onCheckedChange = {
                        enabled = it
                        analytics.setCollectionEnabled(it)
                    },
                )
            }
        }
    }
}

/** Appearance control — System / Light / Dark. Applied app-wide by
 * ThemeModeController (overrides uiMode so every isSystemInDarkTheme() reflects
 * it), so toggling here recomposes the whole app. */
@Composable
private fun AppearanceSection() {
    val context = LocalContext.current
    val selected = ThemeModeController.mode
    val options = listOf(
        ThemeMode.SYSTEM to stringResource(R.string.appearance_system),
        ThemeMode.LIGHT to stringResource(R.string.appearance_light),
        ThemeMode.DARK to stringResource(R.string.appearance_dark),
    )
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        BrandSectionHeader(stringResource(R.string.settings_appearance), icon = Icons.Filled.Contrast)
        BrandCard {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f))
                    .padding(4.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                options.forEach { (mode, label) ->
                    val isSelected = mode == selected
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(9.dp))
                            .background(if (isSelected) MaterialTheme.colorScheme.surface else androidx.compose.ui.graphics.Color.Transparent)
                            .clickable { ThemeModeController.set(context, mode) }
                            .padding(vertical = 10.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            label,
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                            color = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }
}

/** Language row. Opens the OS-native per-app Language screen (Android 13+, via
 * ACTION_APP_LOCALE_SETTINGS with the app's declared locales_config). On older
 * versions there is no per-app language screen, so it falls back to App info. */
@Composable
private fun LanguageSection() {
    // In-app switching (owner request, 2026-08). iOS keeps the native route —
    // Apple offers a per-app Language screen and no supported in-app equivalent —
    // so the two platforms differ here on purpose.
    //
    // AppCompatDelegate rather than the platform LocaleManager: the framework API
    // only exists on API 33+, and minSdk is 26. AppCompat persists the choice
    // itself and replays it on launch, so nothing here needs its own storage.
    val current = AppCompatDelegate.getApplicationLocales()
    val selected = if (current.isEmpty) "" else current[0]?.language.orEmpty()

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        BrandSectionHeader(stringResource(R.string.language_section), icon = Icons.Filled.Language)
        BrandCard {
            Column {
                LanguageOption(R.string.language_system, "", selected)
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                LanguageOption(R.string.language_arabic, "ar", selected)
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                LanguageOption(R.string.language_english, "en", selected)
            }
        }
    }
}

@Composable
private fun LanguageOption(labelRes: Int, tag: String, selected: String) {
    val isSelected = tag == selected
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable {
                // Empty tag == follow the system. Applying the *same* locale again
                // would still recreate the activity, so selecting the current one
                // is a no-op rather than a visible flicker.
                if (!isSelected) {
                    AppCompatDelegate.setApplicationLocales(
                        if (tag.isEmpty()) {
                            LocaleListCompat.getEmptyLocaleList()
                        } else {
                            LocaleListCompat.forLanguageTags(tag)
                        },
                    )
                }
            }
            .padding(vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            stringResource(labelRes),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
        )
        if (isSelected) {
            Icon(
                Icons.Filled.Check,
                contentDescription = stringResource(R.string.language_selected),
                tint = MaterialTheme.colorScheme.primary,
            )
        }
    }
}

@Composable
private fun NotificationsSection(prayerViewModel: PrayerViewModel) {
    var prefs by remember { mutableStateOf(prayerViewModel.currentNotificationPreferences()) }
    fun update(next: PrayerNotificationPreferences) {
        prefs = next
        prayerViewModel.updateNotificationPreferences(next)
    }

    val contentViewModel: ContentReminderViewModel = hiltViewModel()
    var contentPrefs by remember { mutableStateOf(contentViewModel.current()) }
    fun updateContent(next: ContentReminderPreferences) {
        contentPrefs = next
        contentViewModel.update(next)
    }

    val wirdViewModel: WirdReminderViewModel = hiltViewModel()
    var wirdPrefs by remember { mutableStateOf(wirdViewModel.current()) }
    fun updateWird(next: WirdReminderPreferences) {
        wirdPrefs = next
        wirdViewModel.update(next)
    }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        BrandSectionHeader(stringResource(R.string.settings_notifications), icon = Icons.Filled.NotificationsActive)
        BrandCard {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                ToggleRow(stringResource(R.string.settings_notif_adhan_title), stringResource(R.string.settings_notif_adhan_subtitle), prefs.adhanEnabled) {
                    update(prefs.copy(adhanEnabled = it))
                }
                Divider(Modifier.padding(vertical = 4.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.3f))
                ToggleRow(stringResource(R.string.settings_notif_pre_adhan_title), stringResource(R.string.settings_notif_pre_adhan_subtitle), prefs.preAdhanEnabled) {
                    update(prefs.copy(preAdhanEnabled = it))
                }
                if (prefs.preAdhanEnabled) {
                    OffsetRow(stringResource(R.string.settings_notif_minutes_before), prefs.preAdhanOffsetMinutes) {
                        update(prefs.copy(preAdhanOffsetMinutes = it))
                    }
                }
                Divider(Modifier.padding(vertical = 4.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.3f))
                ToggleRow(stringResource(R.string.settings_notif_iqama_title), stringResource(R.string.settings_notif_iqama_subtitle), prefs.iqamaEnabled) {
                    update(prefs.copy(iqamaEnabled = it))
                }
                if (prefs.iqamaEnabled) {
                    // The gap differs per prayer in practice, so each gets its own
                    // stepper. The notice explains why there are five rows here
                    // rather than the single one this used to be.
                    InfoNotice(
                        stringResource(R.string.settings_notif_iqama_notice),
                        modifier = Modifier.padding(vertical = 6.dp),
                    )
                    for (prayer in PrayerNameUi.entries.filter { it.isPrayer }) {
                        OffsetRow(stringResource(prayer.titleRes()), prefs.iqamaOffset(prayer)) {
                            update(prefs.withIqamaOffset(prayer, it))
                        }
                    }
                }
                Divider(Modifier.padding(vertical = 4.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.3f))
                ToggleRow(stringResource(R.string.settings_notif_last_third_title), stringResource(R.string.settings_notif_last_third_subtitle), prefs.lastThirdEnabled) {
                    update(prefs.copy(lastThirdEnabled = it))
                }
                Divider(Modifier.padding(vertical = 4.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.3f))
                // Daily azkar/hadith reminders at random waking-hour times.
                ToggleRow(
                    stringResource(R.string.settings_notif_content_title),
                    stringResource(R.string.settings_notif_content_subtitle),
                    contentPrefs.enabled,
                ) {
                    updateContent(contentPrefs.copy(enabled = it))
                }
                if (contentPrefs.enabled) {
                    CountRow(stringResource(R.string.settings_notif_content_per_day), contentPrefs.perDay) {
                        updateContent(contentPrefs.copy(perDay = it))
                    }
                }
                Divider(Modifier.padding(vertical = 4.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.3f))
                // One "did you complete it?" notification per active wird, once a
                // day, answerable straight from the notification shade.
                ToggleRow(
                    stringResource(R.string.settings_notif_wird_title),
                    stringResource(R.string.settings_notif_wird_subtitle),
                    wirdPrefs.enabled,
                ) {
                    updateWird(wirdPrefs.copy(enabled = it))
                }
                if (wirdPrefs.enabled) {
                    // The four fixed slots each get their own time (client
                    // request). They are on every board and their natural moments
                    // are hours apart — asking about أذكار الصباح at the same time
                    // as قيام الليل is asking about a window that closed.
                    val slotName = fixedWirdNameResolver(LocalContext.current)
                    FixedWirdSlot.entries.forEach { slot ->
                        val time = wirdPrefs.timeFor(slot.wirdId, slot.reminderHour)
                        TimeRow(slotName.name(slot), time.hour, time.minute) { hour, minute ->
                            updateWird(
                                wirdPrefs.withTime(slot.wirdId, WirdReminderTime.of(hour, minute)),
                            )
                        }
                    }
                    // User-created wirds keep the shared time.
                    TimeRow(
                        stringResource(R.string.settings_notif_wird_time_other),
                        wirdPrefs.hour,
                        wirdPrefs.minute,
                    ) { hour, minute ->
                        updateWird(wirdPrefs.copy(hour = hour, minute = minute))
                    }
                }
            }
        }
    }
}

/**
 * Time-of-day picker for the wird reminder. Uses the platform dialog rather than
 * a Compose one so it inherits the user's 12/24-hour system setting — a worship
 * app showing 8:00 PM to someone whose phone is on 24h reads as a bug.
 */
@Composable
private fun TimeRow(label: String, hour: Int, minute: Int, onChange: (Int, Int) -> Unit) {
    val context = LocalContext.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable {
                TimePickerDialog(
                    context,
                    { _, pickedHour, pickedMinute -> onChange(pickedHour, pickedMinute) },
                    hour,
                    minute,
                    DateFormat.is24HourFormat(context),
                ).show()
            }
            .padding(vertical = 10.dp, horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f),
        )
        Text(
            // Formatted through the system locale so Arabic renders Arabic-Indic
            // digits, matching every other number on the screen.
            String.format(Locale.getDefault(), "%02d:%02d", hour, minute),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary,
        )
    }
}

/**
 * Stepper for "how many reminders a day", 0–5. Same shape as [OffsetRow] but over
 * a count rather than minutes, so the bounds and the unit label differ.
 */
@Composable
private fun CountRow(label: String, value: Int, onChange: (Int) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp, horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
        IconButton(
            onClick = { onChange((value - 1).coerceAtLeast(ContentReminderPreferences.COUNT_MIN)) },
            enabled = value > ContentReminderPreferences.COUNT_MIN,
        ) { Icon(Icons.Filled.Remove, contentDescription = stringResource(R.string.settings_stepper_decrease), tint = MaterialTheme.colorScheme.primary) }
        Text(
            stringResource(R.string.settings_notif_content_count_value, value),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.width(48.dp),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        IconButton(
            onClick = { onChange((value + 1).coerceAtMost(ContentReminderPreferences.COUNT_MAX)) },
            enabled = value < ContentReminderPreferences.COUNT_MAX,
        ) { Icon(Icons.Filled.Add, contentDescription = stringResource(R.string.settings_stepper_increase), tint = MaterialTheme.colorScheme.primary) }
    }
}

@Composable
private fun ToggleRow(title: String, subtitle: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            colors = SwitchDefaults.colors(checkedTrackColor = MaterialTheme.colorScheme.primary),
        )
    }
}

@Composable
private fun OffsetRow(label: String, value: Int, onChange: (Int) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp, horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
        IconButton(
            onClick = { onChange((value - 1).coerceAtLeast(PrayerNotificationPreferences.OFFSET_MIN)) },
            enabled = value > PrayerNotificationPreferences.OFFSET_MIN,
        ) { Icon(Icons.Filled.Remove, contentDescription = stringResource(R.string.settings_stepper_decrease), tint = MaterialTheme.colorScheme.primary) }
        Text(
            stringResource(R.string.settings_minutes_value, value),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.width(48.dp),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        IconButton(
            onClick = { onChange((value + 1).coerceAtMost(PrayerNotificationPreferences.OFFSET_MAX)) },
            enabled = value < PrayerNotificationPreferences.OFFSET_MAX,
        ) { Icon(Icons.Filled.Add, contentDescription = stringResource(R.string.settings_stepper_increase), tint = MaterialTheme.colorScheme.primary) }
    }
}

private data class GuideItem(val icon: ImageVector, val title: String, val body: String)

@Composable
private fun FeaturesGuideSection() {
    val items = listOf(
        GuideItem(Icons.Filled.Campaign, stringResource(R.string.settings_notif_adhan_title), stringResource(R.string.settings_guide_adhan_body)),
        GuideItem(Icons.Filled.NotificationsNone, stringResource(R.string.settings_notif_pre_adhan_title), stringResource(R.string.settings_guide_pre_adhan_body)),
        GuideItem(Icons.Filled.Groups, stringResource(R.string.settings_notif_iqama_title), stringResource(R.string.settings_guide_iqama_body)),
        GuideItem(Icons.Filled.NightsStay, stringResource(R.string.settings_notif_last_third_title), stringResource(R.string.settings_guide_last_third_body)),
        GuideItem(Icons.Filled.AutoAwesome, stringResource(R.string.settings_guide_streak_title), stringResource(R.string.settings_guide_streak_body)),
    )
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        BrandSectionHeader(stringResource(R.string.settings_guide_title), icon = Icons.Filled.HelpOutline)
        BrandCard {
            Column {
                items.forEachIndexed { index, item ->
                    GuideRow(item)
                    if (index < items.size - 1) {
                        Divider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.3f))
                    }
                }
            }
        }
    }
}

@Composable
private fun GuideRow(item: GuideItem) {
    var expanded by remember { mutableStateOf(false) }
    Column {
        Row(
            modifier = Modifier.fillMaxWidth().clickable { expanded = !expanded }.padding(vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(item.icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(20.dp))
            Text(item.title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.weight(1f))
            Icon(
                if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        AnimatedVisibility(visible = expanded) {
            Text(
                item.body,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 12.dp),
            )
        }
    }
}

@Composable
private fun AccountSection(viewModel: AccountViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsState()
    val scope = rememberCoroutineScope()
    var isEditing by remember { mutableStateOf(false) }
    var draftName by remember { mutableStateOf("") }

    LaunchedEffect(Unit) { viewModel.load() }

    val profile = state.profile
    val displayName = profile?.displayName?.takeIf { it.isNotBlank() } ?: stringResource(R.string.settings_account_guest)
    val providerText = when (profile?.provider) {
        AccountProvider.APPLE -> stringResource(R.string.settings_account_provider_apple)
        AccountProvider.GOOGLE -> stringResource(R.string.settings_account_provider_google)
        else -> stringResource(R.string.settings_account_provider_guest)
    }

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(
                    Brush.linearGradient(
                        listOf(MaterialTheme.colorScheme.primaryContainer, MaterialTheme.colorScheme.surfaceContainer),
                    ),
                )
                .padding(20.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .background(
                        Brush.linearGradient(
                            listOf(MaterialTheme.colorScheme.primary, MaterialTheme.colorScheme.primary.copy(alpha = 0.75f)),
                        ),
                        CircleShape,
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    if (state.isSignedIn) Icons.Filled.Verified else Icons.Filled.Person,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onPrimary,
                    modifier = Modifier.size(28.dp),
                )
            }
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(displayName, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Icon(
                        if (state.isSignedIn) Icons.Filled.Verified else Icons.Filled.AutoAwesome,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.secondary,
                        modifier = Modifier.size(14.dp),
                    )
                    Text(
                        providerText,
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.secondary,
                    )
                }
            }
            IconButton(onClick = {
                draftName = profile?.displayName.orEmpty()
                isEditing = !isEditing
            }) {
                Icon(Icons.Filled.Edit, contentDescription = stringResource(R.string.settings_account_edit_name), tint = MaterialTheme.colorScheme.primary)
            }
        }

        AnimatedVisibility(visible = isEditing) {
            BrandCard {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedTextField(
                        value = draftName,
                        onValueChange = { draftName = it },
                        placeholder = { Text(stringResource(R.string.settings_account_name_placeholder)) },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.align(Alignment.End)) {
                        TextButton(onClick = { isEditing = false }) { Text(stringResource(R.string.settings_account_cancel)) }
                        Button(
                            enabled = !state.isBusy,
                            onClick = {
                                scope.launch {
                                    viewModel.saveDisplayName(draftName)
                                    isEditing = false
                                }
                            },
                        ) { Text(stringResource(R.string.settings_account_save)) }
                    }
                }
            }
        }

        if (!state.isSignedIn) {
            if (viewModel.isAvailable(AccountProvider.APPLE)) {
                SignInButton(R.string.settings_account_sign_in_apple, enabled = !state.isBusy) {
                    scope.launch { viewModel.signIn(AccountProvider.APPLE) }
                }
            }
            if (viewModel.isAvailable(AccountProvider.GOOGLE)) {
                SignInButton(R.string.settings_account_sign_in_google, enabled = !state.isBusy) {
                    scope.launch { viewModel.signIn(AccountProvider.GOOGLE) }
                }
            }
        }

        val messageText = when (state.message) {
            AccountViewModel.Message.ALREADY_LINKED -> stringResource(R.string.settings_account_error_already_linked)
            AccountViewModel.Message.GENERIC -> stringResource(R.string.settings_account_error_generic)
            AccountViewModel.Message.NONE -> null
        }
        if (messageText != null) {
            Text(messageText, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
        }
    }
}

@Composable
private fun SignInButton(textRes: Int, enabled: Boolean, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(stringResource(textRes), fontWeight = FontWeight.SemiBold)
    }
}
