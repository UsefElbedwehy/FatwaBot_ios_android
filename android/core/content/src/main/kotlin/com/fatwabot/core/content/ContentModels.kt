package com.fatwabot.core.content

import kotlinx.serialization.Serializable

// Mirror of backend/functions/api/content_types.ts and iOS ContentKit's
// ContentModels.swift — already locale-resolved plain strings; property
// names match JSON keys exactly (server + bundled seed share one shape).

@Serializable
data class AzkarItem(
    val id: String,
    val sortOrder: Int,
    val arabicText: String,
    val transliteration: String? = null,
    val translation: String? = null,
    val virtueNote: String? = null,
    val source: String,
    val repeatCount: Int,
)

@Serializable
data class AzkarCategory(
    val id: String,
    val slug: String,
    val name: String,
    val sortOrder: Int,
    val items: List<AzkarItem>,
)

@Serializable
data class AzkarCollection(val version: Int, val categories: List<AzkarCategory>)

@Serializable
data class Dua(
    val id: String,
    val sortOrder: Int,
    val title: String,
    val arabicText: String,
    val transliteration: String? = null,
    val translation: String? = null,
    val source: String,
)

@Serializable
data class DuaCategory(
    val id: String,
    val slug: String,
    val name: String,
    val sortOrder: Int,
    val duas: List<Dua>,
)

@Serializable
data class DuaCollection(val version: Int, val categories: List<DuaCategory>)

@Serializable
data class HadithCollectionSummary(
    val id: String,
    val slug: String,
    val name: String,
    val description: String,
    val entryCount: Int,
)

@Serializable
data class HadithCollectionsResponse(val collections: List<HadithCollectionSummary>)

@Serializable
data class HadithEntry(
    val id: String,
    val number: Int,
    val arabicText: String,
    val translation: String? = null,
    val grading: String,
    val benefitNote: String? = null,
    val source: String,
)

@Serializable
data class HadithCollectionDetail(
    val version: Int,
    val slug: String,
    val name: String,
    val description: String,
    val entries: List<HadithEntry>,
)

@Serializable
data class WirdTemplate(
    val id: String,
    val name: String,
    val description: String,
    val type: String,
    val defaultTarget: Int,
    val defaultUnit: String,
    val defaultFrequency: String,
)

@Serializable
data class WirdTemplatesCollection(val version: Int, val templates: List<WirdTemplate>)
