package com.fatwabot.app.navigation

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.AlternateEmail
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.fatwabot.app.R
import com.fatwabot.core.config.ConfigService
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.designsystem.BrandSectionHeader
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import java.util.Locale

/**
 * The contact channels shown in Settings — email, WhatsApp and social links.
 *
 * Server-driven (ADR-0011, string-pack keys `contact.email`, `contact.whatsapp`,
 * `contact.instagram`, `contact.x`) so an operator can change an address, or
 * switch a channel off, from the dashboard without a release. A field is null
 * when the server supplied nothing or supplied a blank value; nothing is bundled
 * as a fallback on purpose — a made-up address shipped in the APK is worse than
 * no row at all.
 */
data class ContactLinks(
    val email: String? = null,
    val whatsapp: String? = null,
    val instagram: String? = null,
    val x: String? = null,
) {
    /** True when no channel is configured — the whole section is then hidden. */
    val isEmpty: Boolean get() = email == null && whatsapp == null && instagram == null && x == null
}

enum class ContactChannel { EMAIL, WHATSAPP, INSTAGRAM, X }

/**
 * Turns an operator-supplied value into the URI that opens the right app.
 * Accepts either a full URL (pasted out of a browser) or the bare handle /
 * address / phone number the dashboard field asks for, because both are what
 * people actually type. Returns null when nothing usable can be built, and the
 * row then does nothing rather than opening something wrong.
 */
internal fun contactUri(channel: ContactChannel, value: String): String? {
    val trimmed = value.trim()
    if (trimmed.isEmpty()) return null
    val lowered = trimmed.lowercase(Locale.ROOT)
    if (lowered.startsWith("http://") || lowered.startsWith("https://") || lowered.startsWith("mailto:")) {
        return trimmed
    }
    fun handle(raw: String) = raw.removePrefix("@")
    return when (channel) {
        ContactChannel.EMAIL -> "mailto:$trimmed"
        // wa.me wants digits only — operators write "+20 100 123 4567".
        ContactChannel.WHATSAPP -> trimmed.filter { it.isDigit() }
            .takeIf { it.isNotEmpty() }
            ?.let { "https://wa.me/$it" }
        ContactChannel.INSTAGRAM -> "https://instagram.com/${handle(trimmed)}"
        ContactChannel.X -> "https://x.com/${handle(trimmed)}"
    }
}

@EntryPoint
@InstallIn(SingletonComponent::class)
private interface ContactConfigEntryPoint {
    fun configService(): ConfigService
}

/**
 * Resolves the contact channels from the config string packs. Called from the
 * composition root (RootScaffold) and passed down, so [ContactSection] — and any
 * feature module — keeps no dependency on config/network (ADR-0010). Mirrors
 * `tasbeehNotice()` in WorshipTab.kt and iOS `RootTabView.contactLinks`.
 */
@Composable
fun rememberContactLinks(): ContactLinks {
    val context = LocalContext.current
    return remember {
        val configService = EntryPointAccessors.fromApplication(
            context.applicationContext, ContactConfigEntryPoint::class.java,
        ).configService()
        val locale = Locale.getDefault().language
        fun value(key: String) = configService.string(key, locale)?.trim()?.ifEmpty { null }
        ContactLinks(
            email = value("contact.email"),
            whatsapp = value("contact.whatsapp"),
            instagram = value("contact.instagram"),
            x = value("contact.x"),
        )
    }
}

private data class ContactRow(
    val channel: ContactChannel,
    val icon: ImageVector,
    val label: String,
    val value: String,
)

/** "التواصل" — one row per configured channel, following the same section
 * conventions as the rest of Settings (branded header + a single card). */
@Composable
fun ContactSection(links: ContactLinks) {
    val context = LocalContext.current
    // Declaration order == on-screen order; each row disappears with its value.
    val rows = listOfNotNull(
        links.email?.let { ContactRow(ContactChannel.EMAIL, Icons.Filled.Email, stringResource(R.string.settings_contact_email), it) },
        links.whatsapp?.let { ContactRow(ContactChannel.WHATSAPP, Icons.Filled.Chat, stringResource(R.string.settings_contact_whatsapp), it) },
        links.instagram?.let { ContactRow(ContactChannel.INSTAGRAM, Icons.Filled.PhotoCamera, stringResource(R.string.settings_contact_instagram), it) },
        links.x?.let { ContactRow(ContactChannel.X, Icons.Filled.AlternateEmail, stringResource(R.string.settings_contact_x), it) },
    )
    if (rows.isEmpty()) return

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        BrandSectionHeader(stringResource(R.string.settings_contact), icon = Icons.Filled.Email)
        BrandCard {
            Column {
                rows.forEachIndexed { index, row ->
                    val uri = contactUri(row.channel, row.value)
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .let { modifier ->
                                if (uri == null) {
                                    modifier
                                } else {
                                    modifier.clickable {
                                        // No mail/WhatsApp/browser installed is a
                                        // real state on stripped devices; swallow it
                                        // rather than crash the Settings screen.
                                        runCatching {
                                            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(uri)))
                                        }.onFailure { if (it !is ActivityNotFoundException) throw it }
                                    }
                                }
                            }
                            .padding(vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            row.icon,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(20.dp),
                        )
                        androidx.compose.foundation.layout.Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(
                                row.label,
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.Medium,
                                color = MaterialTheme.colorScheme.onSurface,
                            )
                            // The address itself, so it's obvious where the row leads.
                            Text(
                                row.value,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                        Icon(
                            Icons.AutoMirrored.Filled.OpenInNew,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                    if (index < rows.size - 1) {
                        Divider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.3f))
                    }
                }
            }
        }
    }
}
