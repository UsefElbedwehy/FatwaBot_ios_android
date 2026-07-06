package com.fatwabot.feature.azkar

import java.io.File
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/** Persisted mid-session position — mirror of iOS AzkarSessionState
 * (docs/features/azkar.md: "Resume mid-session after app restart same day"). */
@Serializable
data class AzkarSessionState(
    val categoryId: String,
    val currentItemIndex: Int,
    val currentItemCount: Int,
    val lastTouchedAtEpochSeconds: Long,
)

/** Local completion history — feeds "completed today" and, later, M3 streak events. */
@Serializable
data class AzkarCompletionRecord(
    val categoryId: String,
    val completedAtEpochSeconds: Long,
)

interface AzkarStoring {
    fun loadSession(): AzkarSessionState?
    fun saveSession(session: AzkarSessionState?)
    fun loadCompletions(): List<AzkarCompletionRecord>
    fun recordCompletion(record: AzkarCompletionRecord)
}

class FileAzkarStore(private val directory: File) : AzkarStoring {
    private val json = Json { ignoreUnknownKeys = true }
    private val sessionFile = File(directory, "azkar-session.json")
    private val completionsFile = File(directory, "azkar-completions.json")
    private val completionsSerializer = ListSerializer(AzkarCompletionRecord.serializer())

    override fun loadSession(): AzkarSessionState? = runCatching {
        if (!sessionFile.exists()) {
            null
        } else {
            json.decodeFromString(AzkarSessionState.serializer(), sessionFile.readText())
        }
    }.getOrNull()

    override fun saveSession(session: AzkarSessionState?) {
        if (session == null) {
            sessionFile.delete()
            return
        }
        runCatching {
            directory.mkdirs()
            sessionFile.writeText(json.encodeToString(AzkarSessionState.serializer(), session))
        }
    }

    override fun loadCompletions(): List<AzkarCompletionRecord> = runCatching {
        if (!completionsFile.exists()) {
            emptyList()
        } else {
            json.decodeFromString(completionsSerializer, completionsFile.readText())
        }
    }.getOrDefault(emptyList())

    override fun recordCompletion(record: AzkarCompletionRecord) {
        val all = loadCompletions() + record
        runCatching {
            directory.mkdirs()
            completionsFile.writeText(json.encodeToString(completionsSerializer, all))
        }
    }
}
