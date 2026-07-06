package com.fatwabot.feature.prayer

import kotlinx.coroutines.flow.Flow

/** Magnetic/true heading stream in degrees + accuracy — mirror of iOS
 * HeadingProviding (negative accuracy = invalid/calibrating). */
data class HeadingUpdate(val heading: Double, val accuracy: Double)

interface HeadingProviding {
    val supportsHeading: Boolean
    fun headings(): Flow<HeadingUpdate>
}
