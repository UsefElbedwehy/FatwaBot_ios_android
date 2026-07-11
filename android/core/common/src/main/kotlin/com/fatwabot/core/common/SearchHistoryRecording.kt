package com.fatwabot.core.common

/**
 * Search-history recording boundary shared by any feature with an in-app
 * search box (Dua today; Azkar/Hadith Collections once they gain one).
 * Hoisted here (mirrors ActivityEventRecording) so those features never
 * depend on the searchhistory feature module directly (ADR-0010).
 */
interface SearchHistoryRecording {
    /** Fire-and-forget: never blocks or throws to the caller
     * (docs/features/search-history.md — failures are silent). */
    fun record(source: String, queryText: String, locale: String)
}

class NoopSearchHistoryRecording : SearchHistoryRecording {
    override fun record(source: String, queryText: String, locale: String) {}
}
