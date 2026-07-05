package com.fatwabot.core.common

/**
 * Dotted-numeric version comparison for rollout gates ("1.2.10" ≥ "1.2.9").
 * Mirror of iOS CoreKit.SemVer. Non-numeric fragments compare as 0.
 */
object SemVer {
    fun isVersionAtLeast(version: String, minimum: String): Boolean {
        val lhs = components(version)
        val rhs = components(minimum)
        for (i in 0 until maxOf(lhs.size, rhs.size)) {
            val a = lhs.getOrElse(i) { 0 }
            val b = rhs.getOrElse(i) { 0 }
            if (a != b) return a > b
        }
        return true
    }

    private fun components(version: String): List<Int> =
        version.split(".").map { part -> part.takeWhile { it.isDigit() }.toIntOrNull() ?: 0 }
}
