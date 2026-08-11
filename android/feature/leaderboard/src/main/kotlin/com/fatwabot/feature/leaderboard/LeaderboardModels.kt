package com.fatwabot.feature.leaderboard

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class LeaderboardEntry(
    val rank: Int,
    val score: Double,
    @SerialName("display_name") val displayName: String,
)

@Serializable
data class LeaderboardBoard(
    val key: String,
    val name: String,
    val scope: String,
    val period: String,
    val joined: Boolean,
    @SerialName("my_rank") val myRank: Int? = null,
    val entries: List<LeaderboardEntry> = emptyList(),
    /**
     * The current period's calendar bounds as raw ISO-8601 strings (parsed at
     * the display layer, same convention as [com.fatwabot.core.common.QueuedAnalyticsEvent]'s
     * `occurredAt`) — for a "resets on" display, not the scoring window (which
     * ends at "now", not the boundary). `null` for `lifetime` (no reset) and
     * for a `seasonal`/`challenge` board an admin hasn't dated yet.
     */
    @SerialName("period_starts_at") val periodStartsAt: String? = null,
    @SerialName("period_ends_at") val periodEndsAt: String? = null,
)

@Serializable
data class LeaderboardMembership(
    val handle: String,
    @SerialName("publish_name") val publishName: Boolean,
    val city: String? = null,
    val country: String? = null,
)

@Serializable
internal data class ListBoardsResponse(val boards: List<LeaderboardBoard>)

@Serializable
internal data class JoinLeaderboardRequest(
    @SerialName("publish_name") val publishName: Boolean,
    val city: String? = null,
    /**
     * ISO 3166-1 alpha-2. Sent only for country-scope boards; the backend
     * stores it only for those, and rejects the join without it.
     */
    val country: String? = null,
)

@Serializable
internal data class LeftResponse(val left: Boolean)
