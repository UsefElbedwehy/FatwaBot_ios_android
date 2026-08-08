package com.fatwabot.feature.azkar

import com.fatwabot.core.content.AzkarItem
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS AzkarSearchTests. */
class AzkarSearchTest {

    private fun item(id: String, title: String? = null, arabic: String = "", source: String = "") =
        AzkarItem(
            id = id, sortOrder = 0, arabicText = arabic, title = title,
            source = source, repeatCount = 1,
        )

    @Test
    fun `a blank query returns everything`() {
        val items = listOf(item("a", arabic = "سبحان الله"), item("b", arabic = "الحمد لله"))
        assertEquals(2, AzkarSearch.filter(items, "").size)
        assertEquals(2, AzkarSearch.filter(items, "   ").size)
    }

    @Test
    fun `unvowelled query matches fully vowelled matn`() {
        // The whole reason folding exists. The corpus stores harakat; nobody
        // types them. Without this the search box matches nothing, ever — and
        // it fails silently, as "no results" rather than an error.
        val items = listOf(item("a", arabic = "الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا"))
        assertEquals(1, AzkarSearch.filter(items, "الحمد").size)
    }

    @Test
    fun `alif variants are interchangeable`() {
        // Base letters, not marks — stripping diacritics does nothing for these,
        // and dropped hamzas are the most common way a query misses.
        assertEquals(1, AzkarSearch.filter(listOf(item("a", arabic = "الإستيقاظ")), "الاستيقاظ").size)
        assertEquals(1, AzkarSearch.filter(listOf(item("b", arabic = "أذكار")), "اذكار").size)
    }

    @Test
    fun `ya and ta marbuta variants are interchangeable`() {
        assertEquals(1, AzkarSearch.filter(listOf(item("a", arabic = "علی")), "علي").size)
        assertEquals(1, AzkarSearch.filter(listOf(item("b", arabic = "رحمة")), "رحمه").size)
    }

    @Test
    fun `search covers title and source not just matn`() {
        val items = listOf(
            item("a", title = "شكر الله على رد الروح", arabic = "الحمد لله"),
            item("b", arabic = "سبحان الله", source = "صحيح البخاري"),
        )
        assertEquals(listOf("a"), AzkarSearch.filter(items, "شكر").map { it.id })
        assertEquals(listOf("b"), AzkarSearch.filter(items, "البخاري").map { it.id })
    }

    @Test
    fun `an untitled corpus is still searchable`() {
        // The state the library is actually in today: no titles anywhere.
        val items = listOf(item("a", arabic = "اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ"))
        assertTrue(items.all { it.title == null })
        assertEquals(1, AzkarSearch.filter(items, "ذكرك").size)
    }

    @Test
    fun `no match returns empty rather than everything`() {
        assertTrue(AzkarSearch.filter(listOf(item("a", arabic = "سبحان الله")), "قنديل").isEmpty())
    }

    @Test
    fun `latin search is case insensitive`() {
        assertEquals(1, AzkarSearch.filter(listOf(item("a", source = "Sahih Bukhari")), "bukhari").size)
    }
}
