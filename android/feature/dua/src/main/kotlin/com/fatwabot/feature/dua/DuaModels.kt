package com.fatwabot.feature.dua

import java.io.File
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/** Local-only favorite record — mirror of iOS FavoriteDua (docs/features/dua.md,
 * no backend sync in M2). */
@Serializable
data class FavoriteDua(val duaId: String, val addedAtEpochSeconds: Long)

interface DuaStoring {
    fun loadFavorites(): List<FavoriteDua>
    fun saveFavorites(favorites: List<FavoriteDua>)
}

class FileDuaStore(private val file: File) : DuaStoring {
    private val json = Json { ignoreUnknownKeys = true }
    private val serializer = ListSerializer(FavoriteDua.serializer())

    override fun loadFavorites(): List<FavoriteDua> = runCatching {
        if (!file.exists()) emptyList() else json.decodeFromString(serializer, file.readText())
    }.getOrDefault(emptyList())

    override fun saveFavorites(favorites: List<FavoriteDua>) {
        runCatching {
            file.parentFile?.mkdirs()
            val tmp = File(file.parentFile, "${file.name}.tmp")
            tmp.writeText(json.encodeToString(serializer, favorites))
            tmp.renameTo(file)
        }
    }
}

/**
 * Arabic-aware search normalization — mirror of iOS DuaSearch
 * (docs/features/dua.md: "diacritic-insensitive for Arabic — strip tashkeel
 * before matching"). Uses explicit \\uXXXX code-point escapes (not literal
 * combining marks, unreliable to author/verify inline) for the same ranges
 * as iOS: U+0610-061A, U+064B-065F, U+0670, U+06D6-06DC, U+06DF-06E8,
 * U+06EA-06ED (Arabic tashkeel / Quranic annotation marks).
 */
object DuaSearch {
    private val tashkeel = Regex(
        "[ؐ-ًؚ-ٰٟۖ-ۜ۟-۪ۨ-ۭ]",
    )

    fun normalize(text: String): String = text.replace(tashkeel, "").lowercase().trim()
}
