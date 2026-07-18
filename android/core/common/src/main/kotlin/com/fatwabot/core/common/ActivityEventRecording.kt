package com.fatwabot.core.common

/**
 * Activity-event recording boundary shared by any feature whose completion
 * moments feed the gamification engine (Azkar, Tasbeeh, Awrad, Hadith
 * Collections, ...). Hoisted here (mirrors HapticsProviding) so those
 * features never depend on the gamification feature module directly
 * (ADR-0010: feature -> feature is forbidden).
 */
interface ActivityEventRecording {
    /** Fire-and-forget: queues locally and flushes opportunistically
     * (docs/features/gamification.md). Never blocks or throws to the caller. */
    fun record(eventType: String, metadata: Map<String, String> = emptyMap())
}

class NoopActivityEventRecording : ActivityEventRecording {
    override fun record(eventType: String, metadata: Map<String, String>) {}
}
