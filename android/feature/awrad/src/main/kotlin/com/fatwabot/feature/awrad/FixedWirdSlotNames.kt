package com.fatwabot.feature.awrad

import android.content.Context

/**
 * Android-side name resolution for the fixed slots.
 *
 * Lives here rather than at the DI site because the strings themselves are this
 * module's resources — with non-transitive R classes the app's `R` cannot see
 * them, and duplicating the four keys into the app module would put the labels
 * a user sees somewhere other than the feature that defines them.
 *
 * The resolved string is frozen into `Wird.name` at seeding time — same as a
 * template-created wird, whose name is likewise kept in the locale it was
 * created in.
 */
fun fixedWirdNameResolver(context: Context): FixedWirdSlots.NameResolver = FixedWirdSlots.NameResolver { slot ->
    context.getString(
        when (slot) {
            FixedWirdSlot.QIYAM_AL_LAYL -> R.string.awrad_fixed_qiyam_al_layl
            FixedWirdSlot.DAILY_QURAN -> R.string.awrad_fixed_daily_quran
            FixedWirdSlot.MORNING_AZKAR -> R.string.awrad_fixed_morning_azkar
            FixedWirdSlot.EVENING_AZKAR -> R.string.awrad_fixed_evening_azkar
        },
    )
}
