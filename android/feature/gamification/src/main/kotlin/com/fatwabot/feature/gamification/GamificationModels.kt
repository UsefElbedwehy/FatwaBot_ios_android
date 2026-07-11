package com.fatwabot.feature.gamification

import java.io.File
import java.util.UUID
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/** A locally queued, not-yet-confirmed-synced activity event. */
@Serializable
data class QueuedActivityEvent(
    val clientEventId: String = UUID.randomUUID().toString(),
    val eventType: String,
    val occurredAtEpochSeconds: Long,
    val timezone: String,
    val metadata: Map<String, String> = emptyMap(),
)

/** Persistence boundary for the queue (mirrors TasbeehHistoryStoring). */
interface ActivityEventQueueStoring {
    fun load(): List<QueuedActivityEvent>
    fun save(events: List<QueuedActivityEvent>)
}

class FileActivityEventQueueStore(private val file: File) : ActivityEventQueueStoring {
    private val json = Json { ignoreUnknownKeys = true }
    private val serializer = ListSerializer(QueuedActivityEvent.serializer())

    override fun load(): List<QueuedActivityEvent> = runCatching {
        if (!file.exists()) emptyList() else json.decodeFromString(serializer, file.readText())
    }.getOrDefault(emptyList())

    override fun save(events: List<QueuedActivityEvent>) {
        runCatching {
            file.parentFile?.mkdirs()
            val tmp = File(file.parentFile, "${file.name}.tmp")
            tmp.writeText(json.encodeToString(serializer, events))
            tmp.renameTo(file)
        }
    }
}

// Server profile (GET /v1/gamification/profile)

@Serializable
data class GamificationStreak(
    val key: String,
    val name: String,
    @SerialName("current_length") val currentLength: Int,
    @SerialName("longest_length") val longestLength: Int,
    @SerialName("grace_remaining") val graceRemaining: Int,
)

@Serializable
data class GamificationMission(
    val key: String,
    val name: String,
    val progress: Int,
    val target: Int,
    val window: String,
    @SerialName("ends_at") val endsAt: String? = null,
)

@Serializable
data class GamificationBadge(
    val key: String,
    val name: String,
    @SerialName("icon_ref") val iconRef: String,
    @SerialName("earned_at") val earnedAt: String? = null,
) {
    val isEarned: Boolean get() = earnedAt != null
}

@Serializable
data class GamificationProfile(
    val streaks: List<GamificationStreak> = emptyList(),
    val missions: List<GamificationMission> = emptyList(),
    val badges: List<GamificationBadge> = emptyList(),
) {
    companion object {
        val EMPTY = GamificationProfile()
    }
}
