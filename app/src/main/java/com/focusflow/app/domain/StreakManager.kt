package com.focusflow.app.domain

import com.focusflow.app.data.local.entities.DailyScoreEntity
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

object StreakManager {

    /**
     * Calculates the current continuous productivity streak.
     * A day counts towards the streak if productivity score >= 70 or goals were completed.
     */
    fun calculateStreak(scores: List<DailyScoreEntity>): Int {
        if (scores.isEmpty()) return 1

        val sortedScores = scores.sortedByDescending { it.date }
        var streak = 0
        val calendar = Calendar.getInstance()
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())

        for (scoreEntity in sortedScores) {
            val expectedDate = dateFormat.format(calendar.time)
            if (scoreEntity.date == expectedDate && scoreEntity.score >= 65) {
                streak++
                calendar.add(Calendar.DAY_OF_YEAR, -1)
            } else {
                break
            }
        }

        return streak.coerceAtLeast(1)
    }
}
