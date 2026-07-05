package com.fatwabot.core.content

import com.fatwabot.core.network.ApiClientProtocol
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.Json

/**
 * Content sync — mirror of iOS ContentKit.ContentService. `current` reads are
 * synchronous (cache -> bundled seed -> null); refresh is per-collection
 * independent and silent on failure, so content stays fully usable offline.
 */
class ContentService(
    private val store: ContentFileStore,
    private val client: ApiClientProtocol,
) {
    private val json = Json { ignoreUnknownKeys = true }
    private val mutex = Mutex()

    private val cachedAzkar = mutableMapOf<String, AzkarCollection>()
    private val cachedDuas = mutableMapOf<String, DuaCollection>()
    private val cachedHadithSummaries = mutableMapOf<String, List<HadithCollectionSummary>>()
    private val cachedHadithDetail = mutableMapOf<String, HadithCollectionDetail>() // key: "slug_locale"
    private val cachedWird = mutableMapOf<String, WirdTemplatesCollection>()

    fun azkar(locale: String): AzkarCollection? = cachedAzkar.getOrPut(locale) {
        store.load(AzkarCollection.serializer(), "azkar.$locale") ?: return null
    }

    fun duas(locale: String): DuaCollection? = cachedDuas.getOrPut(locale) {
        store.load(DuaCollection.serializer(), "duas.$locale") ?: return null
    }

    fun hadithCollections(locale: String): List<HadithCollectionSummary> = cachedHadithSummaries.getOrPut(locale) {
        store.load(HadithCollectionsResponse.serializer(), "hadith-collections.$locale")?.collections ?: emptyList()
    }

    fun hadithDetail(slug: String, locale: String): HadithCollectionDetail? {
        val key = "${slug}_$locale"
        return cachedHadithDetail.getOrPut(key) {
            store.load(HadithCollectionDetail.serializer(), "hadith-$slug.$locale") ?: return null
        }
    }

    fun wirdTemplates(locale: String): WirdTemplatesCollection? = cachedWird.getOrPut(locale) {
        store.load(WirdTemplatesCollection.serializer(), "wird-templates.$locale") ?: return null
    }

    suspend fun refreshAzkar(locale: String): Boolean = mutex.withLock {
        val since = azkar(locale)?.version
        val query = sinceQuery(since)
        val raw = runCatching { client.getRaw("v1/content/azkar", query) }.getOrNull() ?: return false
        val fresh = runCatching { json.decodeFromString(AzkarCollection.serializer(), raw) }.getOrNull() ?: return false
        if (fresh == cachedAzkar[locale]) return false
        cachedAzkar[locale] = fresh
        store.save(AzkarCollection.serializer(), fresh, "azkar.$locale")
        true
    }

    suspend fun refreshDuas(locale: String): Boolean = mutex.withLock {
        val since = duas(locale)?.version
        val raw = runCatching { client.getRaw("v1/content/duas", sinceQuery(since)) }.getOrNull() ?: return false
        val fresh = runCatching { json.decodeFromString(DuaCollection.serializer(), raw) }.getOrNull() ?: return false
        if (fresh == cachedDuas[locale]) return false
        cachedDuas[locale] = fresh
        store.save(DuaCollection.serializer(), fresh, "duas.$locale")
        true
    }

    suspend fun refreshHadithCollections(locale: String): Boolean = mutex.withLock {
        val raw = runCatching { client.getRaw("v1/content/hadith-collections") }.getOrNull() ?: return false
        val fresh = runCatching {
            json.decodeFromString(HadithCollectionsResponse.serializer(), raw)
        }.getOrNull() ?: return false
        if (fresh.collections == cachedHadithSummaries[locale]) return false
        cachedHadithSummaries[locale] = fresh.collections
        store.save(HadithCollectionsResponse.serializer(), fresh, "hadith-collections.$locale")
        true
    }

    suspend fun refreshHadithDetail(slug: String, locale: String): Boolean = mutex.withLock {
        val key = "${slug}_$locale"
        val since = hadithDetail(slug, locale)?.version
        val raw = runCatching {
            client.getRaw("v1/content/hadith-collections/$slug", sinceQuery(since))
        }.getOrNull() ?: return false
        val fresh = runCatching {
            json.decodeFromString(HadithCollectionDetail.serializer(), raw)
        }.getOrNull() ?: return false
        if (fresh == cachedHadithDetail[key]) return false
        cachedHadithDetail[key] = fresh
        store.save(HadithCollectionDetail.serializer(), fresh, "hadith-$slug.$locale")
        true
    }

    suspend fun refreshWirdTemplates(locale: String): Boolean = mutex.withLock {
        val since = wirdTemplates(locale)?.version
        val raw = runCatching { client.getRaw("v1/content/wird-templates", sinceQuery(since)) }.getOrNull() ?: return false
        val fresh = runCatching {
            json.decodeFromString(WirdTemplatesCollection.serializer(), raw)
        }.getOrNull() ?: return false
        if (fresh == cachedWird[locale]) return false
        cachedWird[locale] = fresh
        store.save(WirdTemplatesCollection.serializer(), fresh, "wird-templates.$locale")
        true
    }

    private fun sinceQuery(version: Int?): Map<String, String> =
        version?.let { mapOf("since_version" to it.toString()) } ?: emptyMap()
}
