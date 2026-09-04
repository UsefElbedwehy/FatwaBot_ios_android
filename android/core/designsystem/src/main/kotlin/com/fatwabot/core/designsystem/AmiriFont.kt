package com.fatwabot.core.designsystem

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * The Amiri family — the naskh face iOS sets all Arabic scripture in
 * (`AmiriFont.swift`). The .ttf files are the same binaries the iOS package
 * bundles, copied into `res/font/` and renamed to Android's lowercase
 * resource convention.
 *
 * Before this existed Android had no font resource at all, so every dhikr,
 * du'a and hadith fell back to Roboto — which has no naskh calligraphic forms
 * and renders Arabic through a generic fallback. That was the single largest
 * visual divergence between the platforms.
 */
val AmiriFontFamily = FontFamily(
    Font(R.font.amiri_regular, FontWeight.Normal),
    Font(R.font.amiri_bold, FontWeight.Bold),
)

/**
 * Scripture body style: 21sp with 31sp leading, matching iOS's
 * `AmiriFont.regular(21)` + `.lineSpacing(10)`.
 *
 * The generous leading is not decoration — Arabic tashkīl (vowel marks) sit
 * *above* the baseline, and at Material's default 24sp leading they collide
 * with the descenders of the line above.
 */
val ArabicScriptureStyle = TextStyle(
    fontFamily = AmiriFontFamily,
    fontSize = 21.sp,
    lineHeight = 31.sp,
)
