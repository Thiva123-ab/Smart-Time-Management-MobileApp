package com.focusflow.app.data.local.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "ai_insights")
data class AIInsightEntity(
    @PrimaryKey(autoGenerate = true) val insightId: Long = 0,
    val date: String, // ISO yyyy-MM-dd
    val type: String, // ANALYSIS, SCHEDULE, RECOMMENDATION, HABIT
    val message: String,
    val recommendation: String,
    val createdAt: Long = System.currentTimeMillis()
)
