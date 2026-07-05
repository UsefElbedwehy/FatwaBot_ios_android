package com.fatwabot.core.config

import java.io.File
import kotlinx.serialization.json.Json

/**
 * File-backed snapshot store (app files dir; widget-shared once widgets land).
 * Atomic write: a crash mid-save must never corrupt the snapshot.
 */
class FileConfigStore(directory: File) : ConfigStoring {
    private val file = File(directory, "config-snapshot.json")
    private val json = Json { ignoreUnknownKeys = true }

    override fun load(): ConfigSnapshot? =
        runCatching {
            if (!file.exists()) null else json.decodeFromString<ConfigSnapshot>(file.readText())
        }.getOrNull()

    override fun save(snapshot: ConfigSnapshot) {
        runCatching {
            file.parentFile?.mkdirs()
            val tmp = File(file.parentFile, "${file.name}.tmp")
            tmp.writeText(json.encodeToString(ConfigSnapshot.serializer(), snapshot))
            tmp.renameTo(file)
        }
    }
}
