package com.fatwabot.feature.searchhistory

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class SearchHistoryEntry(
    val id: String,
    val source: String,
    @SerialName("query_text") val queryText: String,
    val locale: String,
    @SerialName("created_at") val createdAt: String,
)

@Serializable
internal data class ListSearchHistoryResponse(val entries: List<SearchHistoryEntry>)

@Serializable
internal data class RecordSearchRequest(
    val source: String,
    @SerialName("query_text") val queryText: String,
    val locale: String,
)

@Serializable
internal data class DeletedResponse(val deleted: Boolean)

@Serializable
internal data class ClearedResponse(val cleared: Boolean)
