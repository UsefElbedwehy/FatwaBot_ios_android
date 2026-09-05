package com.fatwabot.core.designsystem

import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * The status colours behind a ruling dot, as specified by the client:
 * green = حلال, red = حرام, blue = إباحة, orange = كراهة.
 *
 * The API emits the full five-fold fiqh scale so nothing is lost server-side,
 * and the fold to four colours happens here, where it is a presentation
 * decision that can change without a deploy:
 *
 *   واجب, مستحب, حلال -> green   (all "do / may do", the permitted family)
 *   مباح               -> blue
 *   مكروه              -> orange
 *   حرام               -> red
 *
 * Folding واجب into green is a real loss of nuance — an obligation is not the
 * same as a permission — and worth revisiting with the client if he wants a
 * fifth colour. It is not a *wrong* colour, which is what matters: nothing that
 * is forbidden ever shows green.
 */
enum class RulingStatus { PERMITTED, MUBAH, MAKRUH, HARAM, NONE }

/** Deliberately not `MaterialTheme.colorScheme` values: these are semantic
 *  status colours the client specified by name, not brand roles, and they must
 *  read the same in light and dark. Chosen for contrast on both surfaces. */
private fun RulingStatus.color(isDark: Boolean): Color? = when (this) {
    RulingStatus.PERMITTED -> if (isDark) Color(0xFF4CAF50) else Color(0xFF2E7D32)
    RulingStatus.MUBAH -> if (isDark) Color(0xFF42A5F5) else Color(0xFF1565C0)
    RulingStatus.MAKRUH -> if (isDark) Color(0xFFFFA726) else Color(0xFFE65100)
    RulingStatus.HARAM -> if (isDark) Color(0xFFEF5350) else Color(0xFFC62828)
    // No colour at all — the question has no ruling to give, so drawing a
    // neutral grey dot would still imply one was assessed.
    RulingStatus.NONE -> null
}

/**
 * The coloured status circle. Renders nothing for [RulingStatus.NONE].
 *
 * A dot alone encodes meaning in colour only, which is invisible to a
 * colour-blind or screen-reader user, so callers must pair it with the ruling's
 * name in text — see the result card, where it sits beside the label.
 */
@Composable
fun RulingDot(
    status: RulingStatus,
    isDark: Boolean,
    modifier: Modifier = Modifier,
    size: Dp = 14.dp,
) {
    val color = status.color(isDark) ?: return
    Surface(color = color, shape = CircleShape, modifier = modifier.size(size)) {}
}
