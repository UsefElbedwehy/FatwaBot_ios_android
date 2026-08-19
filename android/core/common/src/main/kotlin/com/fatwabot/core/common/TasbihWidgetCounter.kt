package com.fatwabot.core.common

import java.io.File
import java.time.LocalDate
import java.time.ZoneId
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * The counter behind the interactive العداد widget. Mirror of iOS
 * `TasbihWidgetCounter`.
 *
 * ## Why this is its own state and not the in-app tasbeeh session
 * The app's tasbeeh feature persists *completed sessions* — a record of finished
 * dhikr, not a live tally. A widget tap is a single increment with no session,
 * no chosen dhikr and no completion, so writing it there would either fabricate
 * sessions or corrupt the history the Journey screen reads. The two counters are
 * separate today; unifying them is a product decision, not something to resolve
 * by accident here.
 *
 * ## Why the day is part of the state
 * A tally with no date silently accumulates across days — someone who counted
 * 100 yesterday opens their phone to a widget claiming 100 today.
 */
@Serializable
data class TasbihWidgetCounter(
    val count: Int = 0,
    /** Local day this tally belongs to, ISO-8601. */
    val day: String = LocalDate.now(ZoneId.systemDefault()).toString(),
) {
    /** The tally as of [today], zeroed if it belongs to an earlier day. */
    fun current(today: LocalDate = LocalDate.now(ZoneId.systemDefault())): Int =
        if (day == today.toString()) count else 0

    fun incremented(today: LocalDate = LocalDate.now(ZoneId.systemDefault())): TasbihWidgetCounter =
        TasbihWidgetCounter(current(today) + 1, today.toString())

    fun reset(today: LocalDate = LocalDate.now(ZoneId.systemDefault())): TasbihWidgetCounter =
        TasbihWidgetCounter(0, today.toString())

    companion object {
        private const val FILE_NAME = "tasbih-widget-counter.json"

        fun store(filesDir: File): TasbihWidgetCounterStore =
            TasbihWidgetCounterStore(File(filesDir, FILE_NAME))
    }
}

/** File-backed store (app files dir, shared with the widget process). */
class TasbihWidgetCounterStore(private val file: File) {
    private val json = Json { ignoreUnknownKeys = true }

    fun read(): TasbihWidgetCounter = runCatching {
        if (!file.exists()) {
            TasbihWidgetCounter()
        } else {
            json.decodeFromString(TasbihWidgetCounter.serializer(), file.readText())
        }
    }.getOrDefault(TasbihWidgetCounter())

    fun write(counter: TasbihWidgetCounter) {
        runCatching {
            file.parentFile?.mkdirs()
            val tmp = File(file.parentFile, "${file.name}.tmp")
            tmp.writeText(json.encodeToString(TasbihWidgetCounter.serializer(), counter))
            tmp.renameTo(file)
        }
    }
}
