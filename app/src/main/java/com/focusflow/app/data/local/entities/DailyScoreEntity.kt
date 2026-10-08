package com.focusflow.app.data.local.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "daily_scores")
data class DailyScoreEntity(
    @PrimaryKey val date: String, // ISO yyyy-MM-dd
    val score: Int, // 0 to 100
    val productiveMinutes: Long,
    val distractingMinutes: Long,
    val goalCompletionPercentage: Int,
    val focusMinutes: Long,
    val calculatedAt: Long = System.currentTimeMillis()
)
