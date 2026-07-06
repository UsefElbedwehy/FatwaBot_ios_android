package com.fatwabot.feature.dua

import com.fatwabot.core.content.Dua
import com.fatwabot.core.content.DuaCategory
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS DuaViewModelTests — both must behave identically. */
class DuaViewModelTest {
    private class InMemoryStore : DuaStoring {
        var favorites: List<FavoriteDua> = emptyList()
        override fun loadFavorites(): List<FavoriteDua> = favorites
        override fun saveFavorites(favorites: List<FavoriteDua>) {
            this.favorites = favorites
        }
    }

    private fun dua(id: String, title: String, arabicText: String, translation: String?) = Dua(
        id = id, sortOrder = 0, title = title, arabicText = arabicText,
        transliteration = null, translation = translation, source = "src",
    )

    private fun category(id: String, duas: List<Dua>) = DuaCategory(id, id, id, 0, duas)

    private val istikhara = dua("istikhara", "دعاء الاستخارة", "اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ", "seeking guidance")
    private val distress = dua("distress", "دعاء الكرب", "لا إله إلا الله", "at times of distress")

    private val fixedNow = Instant.fromEpochSeconds(1_774_000_000)
    private val fixedClock = object : Clock {
        override fun now() = fixedNow
    }

    @Test
    fun `search is null when query empty`() {
        val viewModel = DuaViewModel(null, InMemoryStore(), fixedClock)
        assertNull("empty query must mean 'not searching', not 'no results'", viewModel.state.value.searchResults)
    }

    @Test
    fun `search matches arabic title and translation`() {
        val viewModel = DuaViewModel(null, InMemoryStore(), fixedClock)
        viewModel.setCategories(listOf(category("daily", listOf(istikhara, distress))))

        viewModel.updateSearchQuery("الاستخارة")
        assertEquals(listOf("istikhara"), viewModel.state.value.searchResults?.map { it.id })

        viewModel.updateSearchQuery("guidance")
        assertEquals(listOf("istikhara"), viewModel.state.value.searchResults?.map { it.id })
    }

    @Test
    fun `search no matches returns empty list not null`() {
        val viewModel = DuaViewModel(null, InMemoryStore(), fixedClock)
        viewModel.setCategories(listOf(category("daily", listOf(istikhara, distress))))
        viewModel.updateSearchQuery("xyzxyz-no-match")
        assertEquals(emptyList<Dua>(), viewModel.state.value.searchResults)
    }

    @Test
    fun `toggle favorite twice removes it`() {
        val viewModel = DuaViewModel(null, InMemoryStore(), fixedClock)
        assertFalse(viewModel.state.value.isFavorite("d1"))
        viewModel.toggleFavorite("d1")
        assertTrue(viewModel.state.value.isFavorite("d1"))
        viewModel.toggleFavorite("d1")
        assertFalse(viewModel.state.value.isFavorite("d1"))
    }

    @Test
    fun `favorites persist across restarts keyed by stable id`() {
        val store = InMemoryStore()
        val first = DuaViewModel(null, store, fixedClock)
        first.setCategories(listOf(category("daily", listOf(istikhara, distress))))
        first.toggleFavorite("istikhara")

        // Simulate app restart with a *different* category ordering (resync).
        val second = DuaViewModel(null, store, fixedClock)
        second.setCategories(listOf(category("daily", listOf(distress, istikhara))))

        assertTrue("favorite must survive resync/reorder — keyed by id", second.state.value.isFavorite("istikhara"))
        assertEquals(listOf("istikhara"), second.state.value.favoriteDuas.map { it.id })
    }

    @Test
    fun `empty favorites is empty list`() {
        val viewModel = DuaViewModel(null, InMemoryStore(), fixedClock)
        assertEquals(emptyList<Dua>(), viewModel.state.value.favoriteDuas)
    }

    @Test
    fun `most recently favorited first`() {
        var current = fixedNow
        val clock = object : Clock {
            override fun now() = current
        }
        val viewModel = DuaViewModel(null, InMemoryStore(), clock)
        viewModel.setCategories(listOf(category("daily", listOf(istikhara, distress))))

        current = fixedNow
        viewModel.toggleFavorite("istikhara")
        current = Instant.fromEpochSeconds(fixedNow.epochSeconds + 10)
        viewModel.toggleFavorite("distress")

        assertEquals(listOf("distress", "istikhara"), viewModel.state.value.favoriteDuas.map { it.id })
    }
}
