package com.fatwabot.app.navigation

import androidx.annotation.StringRes
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Star
import androidx.compose.ui.graphics.vector.ImageVector
import com.fatwabot.app.R

/** The four top-level destinations (design direction §3). */
enum class AppTab(
    val route: String,
    @StringRes val titleRes: Int,
    val icon: ImageVector,
) {
    HOME("home", R.string.tab_home, Icons.Filled.Home),
    WORSHIP("worship", R.string.tab_worship, Icons.Filled.Star),
    JOURNEY("journey", R.string.tab_journey, Icons.Filled.Person),
    SETTINGS("settings", R.string.tab_settings, Icons.Filled.Settings),
}
