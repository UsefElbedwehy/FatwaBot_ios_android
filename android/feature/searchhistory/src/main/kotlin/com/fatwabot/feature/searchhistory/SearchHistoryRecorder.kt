package com.fatwabot.feature.searchhistory

import com.fatwabot.core.common.SearchHistoryRecording
import com.fatwabot.core.network.AuthenticatedApiClientProtocol
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json

/** Concrete SearchHistoryRecording — the thing Dua (and any future searchable
 * feature) is injected with. Fire-and-forget: failures are silent
 * (docs/features/search-history.md), never surfaced to the search UI. */
class SearchHistoryRecorder(
    private val client: AuthenticatedApiClientProtocol,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
) : SearchHistoryRecording {
    private val json = Json { ignoreUnknownKeys = true }

    override fun record(source: String, queryText: String, locale: String) {
        scope.launch {
            runCatching {
                val body = json.encodeToString(
                    RecordSearchRequest.serializer(),
                    RecordSearchRequest(source = source, queryText = queryText, locale = locale),
                )
                client.postRaw("v1/search-history", body)
            }
        }
    }
}
