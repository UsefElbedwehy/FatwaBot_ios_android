package com.fatwabot.feature.hadith

import java.io.File
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** Local reading progress for one collection — mirror of iOS HadithProgress
 * (docs/features/hadith-collections.md). `readNumbers` is a set — re-reading
 * an entry never double counts. */
@Serializable
data class HadithProgress(
    val readNumbers: Set<Int> = emptySet(),
    val lastReadNumber: Int? = null,
)

interface HadithStoring {
    fun loadProgress(): Map<String, HadithProgress>
    fun saveProgress(progress: Map<String, HadithProgress>)
}

class FileHadithStore(private val file: File) : HadithStoring {
    private val json = Json { ignoreUnknownKeys = true }
    private val serializer = kotlinx.serialization.serializer<Map<String, HadithProgress>>()

    override fun loadProgress(): Map<String, HadithProgress> = runCatching {
        if (!file.exists()) emptyMap() else json.decodeFromString(serializer, file.readText())
    }.getOrDefault(emptyMap())

    override fun saveProgress(progress: Map<String, HadithProgress>) {
        runCatching {
            file.parentFile?.mkdirs()
            val tmp = File(file.parentFile, "${file.name}.tmp")
            tmp.writeText(json.encodeToString(serializer, progress))
            tmp.renameTo(file)
        }
    }
}
