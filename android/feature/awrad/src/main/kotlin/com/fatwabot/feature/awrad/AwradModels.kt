package com.fatwabot.feature.awrad

import java.io.File
import java.util.UUID
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/** A user-created wird instance — mirror of iOS Wird (docs/features/awrad.md).
 * `wird_templates` from the backend supply guided-creation starting points;
 * the instance itself is fully local in M2. */
@Serializable
data class Wird(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val type: String,
    val target: Int,
    val unit: String,
    val frequency: String,
    val createdAtEpochSeconds: Long,
    val archivedAtEpochSeconds: Long? = null,
) {
    val isActive: Boolean get() = archivedAtEpochSeconds == null
}

/** One wird's tally for one local calendar day (`dateKey` = "yyyy-MM-dd"). */
@Serializable
data class WirdDailyProgress(val wirdId: String, val dateKey: String, val count: Int)

/** Recorded when all active wirds meet their target on a given day (the
 * concept demo's "أتممت وردي اليوم" moment) — one record per day, idempotent. */
@Serializable
data class WirdDayCompletionRecord(val dateKey: String, val completedAtEpochSeconds: Long)

/** Lifetime aggregation mirroring the concept demo's four-stat row: total
 * dhikr count, completed days, Qur'an pages, salawat count. */
data class WirdStats(
    val totalDhikrCount: Int,
    val completedDaysCount: Int,
    val quranPagesCount: Int,
    val salawatCount: Int,
) {
    companion object {
        private const val QURAN_UNIT = "pages"
        private const val SALAWAT_TYPE = "salawat"

        fun compute(
            wirds: List<Wird>,
            progress: List<WirdDailyProgress>,
            dayCompletions: List<WirdDayCompletionRecord>,
        ): WirdStats {
            val wirdsById = wirds.associateBy { it.id }
            var totalDhikr = 0
            var quranPages = 0
            var salawat = 0
            for (entry in progress) {
                val wird = wirdsById[entry.wirdId] ?: continue
                if (wird.unit == QURAN_UNIT) {
                    quranPages += entry.count
                } else {
                    totalDhikr += entry.count
                }
                if (wird.type == SALAWAT_TYPE) {
                    salawat += entry.count
                }
            }
            return WirdStats(totalDhikr, dayCompletions.size, quranPages, salawat)
        }
    }
}

interface WirdStoring {
    fun loadWirds(): List<Wird>
    fun saveWirds(wirds: List<Wird>)
    fun loadProgress(): List<WirdDailyProgress>
    fun saveProgress(progress: List<WirdDailyProgress>)
    fun loadDayCompletions(): List<WirdDayCompletionRecord>
    fun recordDayCompletion(record: WirdDayCompletionRecord)
}

class FileWirdStore(private val directory: File) : WirdStoring {
    private val json = Json { ignoreUnknownKeys = true }
    private val wirdsFile = File(directory, "awrad-wirds.json")
    private val progressFile = File(directory, "awrad-progress.json")
    private val completionsFile = File(directory, "awrad-day-completions.json")

    private val wirdsSerializer = ListSerializer(Wird.serializer())
    private val progressSerializer = ListSerializer(WirdDailyProgress.serializer())
    private val completionsSerializer = ListSerializer(WirdDayCompletionRecord.serializer())

    private fun <T> readOrEmpty(file: File, serializer: kotlinx.serialization.KSerializer<List<T>>): List<T> =
        runCatching {
            if (!file.exists()) emptyList() else json.decodeFromString(serializer, file.readText())
        }.getOrDefault(emptyList())

    private fun <T> write(file: File, serializer: kotlinx.serialization.KSerializer<List<T>>, value: List<T>) {
        runCatching {
            directory.mkdirs()
            val tmp = File(directory, "${file.name}.tmp")
            tmp.writeText(json.encodeToString(serializer, value))
            tmp.renameTo(file)
        }
    }

    override fun loadWirds(): List<Wird> = readOrEmpty(wirdsFile, wirdsSerializer)
    override fun saveWirds(wirds: List<Wird>) = write(wirdsFile, wirdsSerializer, wirds)
    override fun loadProgress(): List<WirdDailyProgress> = readOrEmpty(progressFile, progressSerializer)
    override fun saveProgress(progress: List<WirdDailyProgress>) = write(progressFile, progressSerializer, progress)
    override fun loadDayCompletions(): List<WirdDayCompletionRecord> =
        readOrEmpty(completionsFile, completionsSerializer)

    override fun recordDayCompletion(record: WirdDayCompletionRecord) {
        val all = loadDayCompletions() + record
        write(completionsFile, completionsSerializer, all)
    }
}
