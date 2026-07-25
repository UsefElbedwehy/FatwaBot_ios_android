package com.fatwabot.core.common

import android.net.Uri

/**
 * Canonical in-app destinations reachable from outside the app — today from
 * widgets, tomorrow from push payloads or a website.
 *
 * Lives in `:core:common` so the `:app` module and the `:widget` module build
 * their URIs from the SAME definition. A widget that hardcodes
 * `"fatwabot://prayer"` while the app parses `"prayer-times"` fails silently —
 * the tap just opens Home and nobody notices for weeks — so the scheme and its
 * parsing are defined exactly once, here.
 *
 * Mirrors iOS `CoreKit.DeepLink`; keep the two in sync, and keep [SCHEME] in
 * sync with the intent-filter in the app's AndroidManifest.
 */
enum class DeepLink(val host: String) {
    HOME("home"),
    PRAYER("prayer"),
    QIBLA("qibla"),
    TASBEEH("tasbeeh"),
    AZKAR("azkar"),
    DUA("dua"),
    AWRAD("awrad"),
    HADITH("hadith"),
    JOURNEY("journey"),
    ;

    /** `fatwabot://prayer` */
    val uri: Uri get() = Uri.parse("$SCHEME://$host")

    companion object {
        const val SCHEME = "fatwabot"

        /** Parses an incoming URI, ignoring anything that isn't ours. */
        fun from(uri: Uri?): DeepLink? = parse(uri?.toString())

        /**
         * The actual parsing, kept off `android.net.Uri` so it is unit-testable
         * on the plain JVM — `Uri.parse` is a stubbed no-op outside an
         * instrumented/Robolectric run, which would leave the fragile half of
         * the widget→app hand-off untested.
         */
        fun parse(raw: String?): DeepLink? {
            val text = raw?.trim() ?: return null
            val separator = text.indexOf("://")
            if (separator <= 0) return null
            if (!text.substring(0, separator).equals(SCHEME, ignoreCase = true)) return null
            // Accept both `fatwabot://dua` (authority) and `fatwabot:///dua`
            // (empty authority, path only) so a malformed link still lands.
            val candidate = text.substring(separator + 3)
                .substringBefore('?')
                .substringBefore('#')
                .trim('/')
                .lowercase()
            return entries.firstOrNull { it.host == candidate }
        }
    }
}
