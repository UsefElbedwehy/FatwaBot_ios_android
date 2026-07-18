package com.fatwabot.core.common

import java.io.File
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Tracks whether the value-first onboarding flow (docs/features/onboarding.md)
 * has been completed on this install. Local-only — onboarding runs before any
 * identity exists, so there is nothing server-side to attach this to; a
 * reinstall sees onboarding again, which is acceptable. Mirrors iOS
 * OnboardingCompletionStore.
 */
class OnboardingCompletionStore(private val file: File) {
    @Serializable
    private data class Payload(val completed: Boolean, val completedAtEpochSeconds: Long)

    private val json = Json { ignoreUnknownKeys = true }

    fun isCompleted(): Boolean = runCatching {
        if (!file.exists()) false else json.decodeFromString(Payload.serializer(), file.readText()).completed
    }.getOrDefault(false)

    fun markCompleted(atEpochSeconds: Long) {
        runCatching {
            file.parentFile?.mkdirs()
            val tmp = File(file.parentFile, "${file.name}.tmp")
            tmp.writeText(json.encodeToString(Payload.serializer(), Payload(true, atEpochSeconds)))
            tmp.renameTo(file)
        }
    }
}
