package com.fatwabot.feature.tasbeeh

import com.fatwabot.core.common.HapticsProviding
import java.io.File
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/** Mirror of iOS DhikrPreset (docs/features/tasbeeh.md). */
data class DhikrPreset(val id: String, val arabicText: String) {
    companion object {
        val CUSTOM = DhikrPreset("custom", "")

        val bundled = listOf(
            DhikrPreset("subhanallah", "سبحان الله"),
            DhikrPreset("alhamdulillah", "الحمد لله"),
            DhikrPreset("allahu_akbar", "الله أكبر"),
            DhikrPreset("la_ilaha_illallah", "لا إله إلا الله"),
            DhikrPreset("subhanallahi_wabihamdihi", "سبحان الله وبحمده"),
            DhikrPreset("astaghfirullah", "أستغفر الله"),
        )

        val commonTargets = listOf(33, 99, 100, 1000)
    }
}

@Serializable
data class TasbeehHistoryEntry(
    val id: String,
    val presetId: String?,
    val customText: String?,
    val target: Int,
    val actualCount: Int,
    val completedAtEpochSeconds: Long,
)

data class TasbeehStats(val totalCount: Int, val setsCompleted: Int) {
    companion object {
        fun from(history: List<TasbeehHistoryEntry>) = TasbeehStats(
            totalCount = history.sumOf { it.actualCount },
            setsCompleted = history.size,
        )
    }
}

/** Persistence boundary (mirrors core:config's FileConfigStore pattern). */
interface TasbeehHistoryStoring {
    fun load(): List<TasbeehHistoryEntry>
    fun save(history: List<TasbeehHistoryEntry>)
}

class FileTasbeehHistoryStore(private val file: File) : TasbeehHistoryStoring {
    private val json = Json { ignoreUnknownKeys = true }

    private val serializer = ListSerializer(TasbeehHistoryEntry.serializer())

    override fun load(): List<TasbeehHistoryEntry> = runCatching {
        if (!file.exists()) emptyList() else json.decodeFromString(serializer, file.readText())
    }.getOrDefault(emptyList())

    override fun save(history: List<TasbeehHistoryEntry>) {
        runCatching {
            file.parentFile?.mkdirs()
            val tmp = File(file.parentFile, "${file.name}.tmp")
            tmp.writeText(json.encodeToString(serializer, history))
            tmp.renameTo(file)
        }
    }
}
