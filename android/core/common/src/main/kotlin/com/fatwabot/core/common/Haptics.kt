package com.fatwabot.core.common

/**
 * Haptics boundary shared across features (mirrors iOS CoreKit.HapticsProviding —
 * hoisted here rather than living in one feature module so a second feature
 * needing haptics doesn't have to depend on the first, feature, which ADR-0010
 * forbids).
 */
interface HapticsProviding {
    fun tick()
    fun targetReached()
}

class NoopHaptics : HapticsProviding {
    override fun tick() {}
    override fun targetReached() {}
}
