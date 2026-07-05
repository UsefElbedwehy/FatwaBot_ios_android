package com.fatwabot.core.content

import java.io.File
import kotlinx.serialization.DeserializationStrategy
import kotlinx.serialization.SerializationStrategy
import kotlinx.serialization.json.Json

/**
 * Generic per-collection-per-locale cache (docs/features/content-pipeline.md).
 * Falls back to the bundled seed shipped as JVM classpath resources under
 * the content resource directory (works identically in production and
 * plain JUnit tests — mirror of iOS ContentFileStore's Bundle.module
 * pattern, no Android Context/Robolectric required).
 */
class ContentFileStore(
    private val cacheDirectory: File,
    private val classLoader: ClassLoader = ContentFileStore::class.java.classLoader!!,
) {
    private val json = Json { ignoreUnknownKeys = true }

    fun <T> load(serializer: DeserializationStrategy<T>, key: String): T? {
        readCache(serializer, key)?.let { return it }
        return readSeed(serializer, key)
    }

    fun <T> save(serializer: SerializationStrategy<T>, value: T, key: String) {
        runCatching {
            cacheDirectory.mkdirs()
            val tmp = File(cacheDirectory, "content-$key.json.tmp")
            tmp.writeText(json.encodeToString(serializer, value))
            tmp.renameTo(cacheFile(key))
        }
    }

    private fun <T> readCache(serializer: DeserializationStrategy<T>, key: String): T? = runCatching {
        val file = cacheFile(key)
        if (!file.exists()) null else json.decodeFromString(serializer, file.readText())
    }.getOrNull()

    private fun <T> readSeed(serializer: DeserializationStrategy<T>, key: String): T? = runCatching {
        classLoader.getResourceAsStream("content/$key.json")?.use { stream ->
            json.decodeFromString(serializer, stream.readBytes().toString(Charsets.UTF_8))
        }
    }.getOrNull()

    private fun cacheFile(key: String) = File(cacheDirectory, "content-$key.json")
}
