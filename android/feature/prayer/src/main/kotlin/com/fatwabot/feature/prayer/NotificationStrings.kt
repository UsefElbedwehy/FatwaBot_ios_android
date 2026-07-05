package com.fatwabot.feature.prayer

import android.content.Context

/**
 * Maps NotificationPlanner template keys to Android string resources.
 * M1: bundled. Admin-editable template packs (ADR-0013) overlay here in M3.
 */
fun notificationString(context: Context, key: String): String {
    val resName = key.replace('.', '_')
    val resId = context.resources.getIdentifier(resName, "string", context.packageName)
    return if (resId != 0) context.getString(resId) else key
}
