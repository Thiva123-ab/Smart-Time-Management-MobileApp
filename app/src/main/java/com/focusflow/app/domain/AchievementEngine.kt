package com.focusflow.app.domain

import com.focusflow.app.data.local.entities.AchievementEntity

object AchievementEngine {

    fun evaluateAchievements(
        currentAchievements: List<AchievementEntity>,
        completedFocusSessionsCount: Int,
        totalFocusMinutes: Long,
        streakDays: Int,
        completedGoalsCount: Int,
        socialMediaOverBudget: Boolean
    ): List<AchievementEntity> {
        val now = System.currentTimeMillis()

        return currentAchievements.map { item ->
            if (item.isUnlocked) return@map item // Already unlocked

            val shouldUnlock = when (item.achievementId) {
                "first_focus" -> completedFocusSessionsCount >= 1
                "focus_10_hours" -> totalFocusMinutes >= 600
                "streak_3_days" -> streakDays >= 3
                "streak_7_days" -> streakDays >= 7
                "digital_balance" -> !socialMediaOverBudget && completedFocusSessionsCount >= 1
                "goals_master" -> completedGoalsCount >= 20
                else -> false
            }

            if (shouldUnlock) {
                item.copy(isUnlocked = true, unlockedDate = now)
            } else {
                item
            }
        }
    }
}
