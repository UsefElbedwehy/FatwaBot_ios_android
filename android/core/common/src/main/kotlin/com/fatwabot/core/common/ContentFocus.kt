package com.fatwabot.core.common

/**
 * Which specific azkar/hadith item a content-reminder tap should land on — set
 * alongside a [DeepLink] only for that notification kind, `null` for every
 * other route (widgets and Live Activities have never known about a specific
 * item, only a tab). Mirror of iOS `ContentFocus`.
 *
 * Enough for the receiving screen to select the right chip and scroll to the
 * item: [categorySlug] picks the category/collection, [contentId] picks the
 * entry inside it.
 */
data class ContentFocus(val contentId: String, val categorySlug: String?)
