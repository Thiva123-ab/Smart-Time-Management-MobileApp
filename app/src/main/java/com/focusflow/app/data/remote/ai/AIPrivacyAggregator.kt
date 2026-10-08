package com.focusflow.app.data.remote.ai

import com.focusflow.app.data.local.entities.AppUsageEntity
import com.focusflow.app.domain.AppCategoryManager

data class AnonymousUsageSummary(
    val date: String,
    val productiveMinutes: Long,
    val socialMediaMinutes: Long,
    val entertainmentMinutes: Long,
    val gamingMinutes: Long,
    val otherMinutes: Long,
    val focusSessionCount: Int,
    val goalCompletionPercentage: Int,
    val topDistractionCategory: String
)

object AIPrivacyAggregator {

    /**
     * Anonymizes and aggregates raw app usage data before sending to any external API.
     * Raw package names, window titles, or sensitive app lists are never exposed.
     */
    fun createSanitizedSummary(
        date: String,
        usages: List<AppUsageEntity>,
        focusCount: Int,
        goalCompletion: Int
    ): AnonymousUsageSummary {
        val productive = usages.filter { AppCategoryManager.isProductive(it.category) }.sumOf { it.durationMinutes }
        val social = usages.filter { it.category == AppCategoryManager.CATEGORY_SOCIAL }.sumOf { it.durationMinutes }
        val entertainment = usages.filter { it.category == AppCategoryManager.CATEGORY_ENTERTAINMENT }.sumOf { it.durationMinutes }
        val gaming = usages.filter { it.category == AppCategoryManager.CATEGORY_GAMING }.sumOf { it.durationMinutes }
        val others = usages.filter { !AppCategoryManager.isProductive(it.category) && !AppCategoryManager.isDistracting(it.category) }.sumOf { it.durationMinutes }

        val topDistraction = when {
            social >= entertainment && social >= gaming -> "Social Media"
            entertainment >= social && entertainment >= gaming -> "Entertainment"
            else -> "Gaming"
        }

        return AnonymousUsageSummary(
            date = date,
            productiveMinutes = productive,
            socialMediaMinutes = social,
            entertainmentMinutes = entertainment,
            gamingMinutes = gaming,
            otherMinutes = others,
            focusSessionCount = focusCount,
            goalCompletionPercentage = goalCompletion,
            topDistractionCategory = topDistraction
        )
    }
}
