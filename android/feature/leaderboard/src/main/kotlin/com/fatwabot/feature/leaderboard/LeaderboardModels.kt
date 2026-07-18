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
)

@Serializable
data class LeaderboardMembership(
    val handle: String,
    @SerialName("publish_name") val publishName: Boolean,
    val city: String? = null,
)

@Serializable
internal data class ListBoardsResponse(val boards: List<LeaderboardBoard>)

@Serializable
internal data class JoinLeaderboardRequest(
    @SerialName("publish_name") val publishName: Boolean,
    val city: String? = null,
)

@Serializable
internal data class LeftResponse(val left: Boolean)
