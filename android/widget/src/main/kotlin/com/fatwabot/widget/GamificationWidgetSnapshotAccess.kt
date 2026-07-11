package com.fatwabot.widget

import android.content.Context
import com.fatwabot.core.common.GamificationWidgetSnapshot
import com.fatwabot.core.common.GamificationWidgetSnapshotStore
import java.io.File

/**
 * Single source for the gamification widget snapshot file path, shared by the
 * app (writer) and the widget receivers (readers). Mirrors WidgetSnapshotAccess.
 */
object GamificationWidgetSnapshotAccess {
    const val FILE_NAME = "gamification-widget-snapshot.json"

    fun store(context: Context): GamificationWidgetSnapshotStore =
        GamificationWidgetSnapshotStore(File(context.filesDir, FILE_NAME))

    fun read(context: Context): GamificationWidgetSnapshot? = store(context).read()
}
