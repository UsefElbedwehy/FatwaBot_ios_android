package com.fatwabot.widget

import android.content.Context
import com.fatwabot.core.prayer.PrayerWidgetSnapshot
import com.fatwabot.core.prayer.WidgetSnapshotStore
import java.io.File

/**
 * Single source for the widget snapshot file path, shared by the app (writer)
 * and the widget receivers (readers). Lives in the app files dir — Glance widget
 * receivers run in the app process, so no separate storage is needed.
 */
object WidgetSnapshotAccess {
    const val FILE_NAME = "prayer-widget-snapshot.json"

    fun store(context: Context): WidgetSnapshotStore =
        WidgetSnapshotStore(File(context.filesDir, FILE_NAME))

    fun read(context: Context): PrayerWidgetSnapshot? = store(context).read()
}
