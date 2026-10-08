package com.focusflow.app.domain

data class ScoreBreakdown(
    val totalScore: Int,
    val goalPoints: Int,
    val productiveRatioPoints: Int,
    val focusPoints: Int,
    val distractionControlPoints: Int,
    val consistencyPoints: Int,
    val advice: String
)

object ProductivityScoreEngine {

    /**
     * Calculates the daily productivity score (0 - 100)
     * Model (Section 13 & 50):
     * - Goal Completion: 30 points
     * - Productive Ratio: 25 points
     * - Focus Sessions: 20 points
     * - Distraction Control: 15 points
     * - Consistency: 10 points
     */
    fun calculateScore(
        goalCompletionPercentage: Int, // 0 - 100
        productiveMinutes: Long,
        distractingMinutes: Long,
        focusMinutes: Long,
        limitViolations: Int = 0,
        streakDays: Int = 1
    ): ScoreBreakdown {
        // 1. Goal Completion (Max 30)
        val goalPoints = ((goalCompletionPercentage.coerceIn(0, 100) * 30) / 100)

        // 2. Productive Ratio (Max 25)
        val totalActiveMinutes = productiveMinutes + distractingMinutes
        val productiveRatioPoints = if (totalActiveMinutes > 0) {
            val ratio = productiveMinutes.toDouble() / totalActiveMinutes.toDouble()
            (ratio * 25).toInt().coerceIn(0, 25)
        } else {
            15 // Neutral default if early in the morning
        }

        // 3. Focus Sessions (Max 20)
        // Full points awarded at 120 minutes of focus time
        val focusTarget = 120L
        val focusPoints = ((focusMinutes.coerceAtMost(focusTarget).toDouble() / focusTarget.toDouble()) * 20)
            .toInt().coerceIn(0, 20)

        // 4. Distraction Control (Max 15)
        // Base 15 points, deducted for excessive distracting minutes and limit violations
        var distractionPoints = 15
        if (distractingMinutes > 120) {
            val excessHours = ((distractingMinutes - 120) / 30).toInt()
            distractionPoints -= excessHours * 3
        }
        distractionPoints -= (limitViolations * 4)
        val finalDistractionPoints = distractionPoints.coerceIn(0, 15)

        // 5. Consistency / Streak (Max 10)
        val consistencyPoints = when {
            streakDays >= 7 -> 10
            streakDays >= 3 -> 8
            streakDays >= 1 -> 6
            else -> 4
        }

        val total = (goalPoints + productiveRatioPoints + focusPoints + finalDistractionPoints + consistencyPoints)
            .coerceIn(0, 100)

        val advice = when {
            total >= 85 -> "Outstanding productivity today! You stayed deeply focused and controlled distractions seamlessly."
            total >= 70 -> "Great job! A solid day of work. Watch out for afternoon social media spikes to reach 90+."
            total >= 50 -> "Decent balance. Consider starting a 45-minute Focus Session to elevate your score."
            else -> "High distraction detected today. Try setting stricter app limits and complete at least one study goal tomorrow."
        }

        return ScoreBreakdown(
            totalScore = total,
            goalPoints = goalPoints,
            productiveRatioPoints = productiveRatioPoints,
            focusPoints = focusPoints,
            distractionControlPoints = finalDistractionPoints,
            consistencyPoints = consistencyPoints,
            advice = advice
        )
    }
}
