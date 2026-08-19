package com.fatwabot.app.navigation

import androidx.annotation.StringRes
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.ui.graphics.vector.ImageVector
import com.fatwabot.app.R

/** Top-level destinations for the floating bar (client redesign): Worship (left)
 * · Home (center) · Settings (right). Journey lives in the Worship grid now. */
enum class AppTab(
    val route: String,
    @StringRes val titleRes: Int,
    val icon: ImageVector,
) {
    WORSHIP("worship", R.string.tab_worship, Icons.Filled.GridView),
    HOME("home", R.string.tab_home, Icons.Filled.Home),
    SETTINGS("settings", R.string.tab_settings, Icons.Filled.Settings),
}
