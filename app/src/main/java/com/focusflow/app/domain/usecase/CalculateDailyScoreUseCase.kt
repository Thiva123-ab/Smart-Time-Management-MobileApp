package com.focusflow.app.domain.usecase

import com.focusflow.app.data.local.entities.DailyScoreEntity
import com.focusflow.app.data.repository.AnalyticsRepository
import com.focusflow.app.data.repository.AppUsageRepository
import com.focusflow.app.data.repository.FocusRepository
import com.focusflow.app.data.repository.GoalRepository
import com.focusflow.app.domain.AppCategoryManager
import com.focusflow.app.domain.ProductivityScoreEngine
import com.focusflow.app.domain.ScoreBreakdown
import kotlinx.coroutines.flow.firstOrNull

class CalculateDailyScoreUseCase(
    private val appUsageRepository: AppUsageRepository,
    private val goalRepository: GoalRepository,
    private val focusRepository: FocusRepository,
    private val analyticsRepository: AnalyticsRepository
) {
    suspend operator fun invoke(date: String = appUsageRepository.getTodayDate()): ScoreBreakdown {
        val usages = appUsageRepository.getUsageForDate(date).firstOrNull() ?: emptyList()
        val totalFocusMinutes = focusRepository.getTotalFocusMinutesForDate(date).firstOrNull() ?: 0L
        val goalPercentage = goalRepository.getGoalCompletionPercentage(date)

        val productiveMinutes = usages.filter { AppCategoryManager.isProductive(it.category) }
            .sumOf { it.durationMinutes }
        val distractingMinutes = usages.filter { AppCategoryManager.isDistracting(it.category) }
            .sumOf { it.durationMinutes }

        val breakdown = ProductivityScoreEngine.calculateScore(
            goalCompletionPercentage = goalPercentage,
            productiveMinutes = productiveMinutes,
            distractingMinutes = distractingMinutes,
            focusMinutes = totalFocusMinutes,
            limitViolations = 0,
            streakDays = 3
        )

        // Persist daily score
        analyticsRepository.recordDailyScore(
            DailyScoreEntity(
                date = date,
                score = breakdown.totalScore,
                productiveMinutes = productiveMinutes,
                distractingMinutes = distractingMinutes,
                goalCompletionPercentage = goalPercentage,
                focusMinutes = totalFocusMinutes
            )
        )

        return breakdown
    }
}
