package com.fatwabot.app.navigation

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.QuestionAnswer
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fatwabot.app.R
import com.fatwabot.core.designsystem.BrandMark
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.brandScreenBackground

/** Search-first Home (client redesign) — parity with iOS SearchHomeScreen.
 * Cards + search open a "coming soon" dialog (M5 AI search is on hold). */
@Composable
fun SearchHome() {
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens
    val cs = MaterialTheme.colorScheme
    var showComingSoon by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .brandScreenBackground(tokens)
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(24.dp))
        BrandMark(modifier = Modifier.size(96.dp), color = cs.primary)
        Text(
            "FATWA BOT",
            fontFamily = FontFamily.Serif,
            fontSize = 30.sp,
            letterSpacing = 4.sp,
            fontWeight = FontWeight.SemiBold,
            color = cs.onSurface,
            modifier = Modifier.padding(top = 8.dp),
        )

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxWidth().padding(vertical = 28.dp),
        ) {
            Box(Modifier.weight(1f).height(1.dp).background(cs.primary.copy(alpha = 0.5f)))
            Icon(Icons.Filled.Star, contentDescription = null, tint = cs.primary, modifier = Modifier.size(18.dp))
            Box(Modifier.weight(1f).height(1.dp).background(cs.primary.copy(alpha = 0.5f)))
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            IntentCard(R.string.home_card_question, Icons.Filled.QuestionAnswer, Modifier.weight(1f)) { showComingSoon = true }
            IntentCard(R.string.home_card_hadith, Icons.AutoMirrored.Filled.MenuBook, Modifier.weight(1f)) { showComingSoon = true }
            IntentCard(R.string.home_card_fatwa, Icons.Filled.Search, Modifier.weight(1f)) { showComingSoon = true }
        }

        Spacer(Modifier.height(26.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp)
                .clip(CircleShape)
                .background(cs.surface)
                .clickable { showComingSoon = true },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier.width(64.dp).fillMaxSize().clip(CircleShape).background(cs.primary),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Filled.Search, contentDescription = null, tint = cs.onPrimary) }
            Text(
                stringResource(R.string.home_search_placeholder),
                color = cs.onSurfaceVariant,
                modifier = Modifier.padding(start = 16.dp),
            )
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(top = 22.dp, start = 8.dp, end = 8.dp),
        ) {
            Icon(Icons.Filled.Star, contentDescription = null, tint = cs.secondary, modifier = Modifier.size(14.dp))
            Text(
                stringResource(R.string.home_tagline),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = cs.primary,
                textAlign = TextAlign.Center,
            )
        }
    }

    if (showComingSoon) {
        AlertDialog(
            onDismissRequest = { showComingSoon = false },
            confirmButton = { TextButton(onClick = { showComingSoon = false }) { Text(stringResource(R.string.common_ok)) } },
            icon = { Icon(Icons.Filled.Star, contentDescription = null, tint = cs.primary) },
            title = { Text(stringResource(R.string.home_coming_soon_title)) },
            text = { Text(stringResource(R.string.home_coming_soon_body)) },
        )
    }
}

@Composable
private fun IntentCard(titleRes: Int, icon: ImageVector, modifier: Modifier, onClick: () -> Unit) {
    val cs = MaterialTheme.colorScheme
    Column(
        modifier = modifier
            .height(118.dp)
            .clip(RoundedCornerShape(22.dp))
            .background(cs.surface)
            .clickable(onClick = onClick)
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(icon, contentDescription = null, tint = cs.primary, modifier = Modifier.size(28.dp))
        Spacer(Modifier.height(12.dp))
        Text(
            stringResource(titleRes),
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Medium,
            color = cs.onSurface,
            textAlign = TextAlign.Center,
        )
    }
}
