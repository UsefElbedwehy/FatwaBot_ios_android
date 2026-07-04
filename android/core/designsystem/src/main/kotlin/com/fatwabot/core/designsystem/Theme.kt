package com.fatwabot.core.designsystem

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

@Composable
fun FatwaBotTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val tokens = if (darkTheme) DarkTokens else LightTokens
    val colorScheme = if (darkTheme) {
        darkColorScheme(
            primary = tokens.primary,
            primaryContainer = tokens.primaryContainer,
            secondary = tokens.accent,
            surface = tokens.surface,
            surfaceContainer = tokens.surfaceElevated,
            onSurface = tokens.onSurface,
            onSurfaceVariant = tokens.onSurfaceSecondary,
            onPrimary = tokens.onPrimary,
            outline = tokens.outline,
            background = tokens.surface,
            onBackground = tokens.onSurface,
        )
    } else {
        lightColorScheme(
            primary = tokens.primary,
            primaryContainer = tokens.primaryContainer,
            secondary = tokens.accent,
            surface = tokens.surface,
            surfaceContainer = tokens.surfaceElevated,
            onSurface = tokens.onSurface,
            onSurfaceVariant = tokens.onSurfaceSecondary,
            onPrimary = tokens.onPrimary,
            outline = tokens.outline,
            background = tokens.surface,
            onBackground = tokens.onSurface,
        )
    }
    MaterialTheme(colorScheme = colorScheme, content = content)
}
