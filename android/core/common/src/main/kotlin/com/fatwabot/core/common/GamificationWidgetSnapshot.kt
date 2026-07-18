package com.fatwabot.core.common

import java.io.File
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * The data the Streak/Daily-Challenge widgets render from — written by the
 * app, read by the Glance widget with zero network (mirror of iOS
 * GamificationWidgetSnapshot). Only the single most relevant streak/mission
 * are kept: widgets show one headline number, not the full profile.
 */
@Serializable
data class GamificationWidgetSnapshot(
    val topStreak: Streak?,
    val dailyChallenge: DailyChallenge?,
    val generatedAtEpochSeconds: Long,
) {
    @Serializable
    data class Streak(
        val name: String,
        val currentLength: Int,
        val longestLength: Int,
        val graceRemaining: Int,
    )

    @Serializable
    data class DailyChallenge(
        val name: String,
        val progress: Int,
        val target: Int,
    )
}

/** File-backed store (app files dir shared with the widget process). */
class GamificationWidgetSnapshotStore(private val file: File) {
    private val json = Json { ignoreUnknownKeys = true }

    fun write(snapshot: GamificationWidgetSnapshot) {
        runCatching {
            file.parentFile?.mkdirs()
            val tmp = File(file.parentFile, "${file.name}.tmp")
            tmp.writeText(json.encodeToString(GamificationWidgetSnapshot.serializer(), snapshot))
            tmp.renameTo(file)
        }
    }

    fun read(): GamificationWidgetSnapshot? = runCatching {
        if (!file.exists()) null else json.decodeFromString<GamificationWidgetSnapshot>(file.readText())
    }.getOrNull()
}
