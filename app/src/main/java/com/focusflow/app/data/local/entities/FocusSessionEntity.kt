package com.focusflow.app.data.local.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "focus_sessions")
data class FocusSessionEntity(
    @PrimaryKey(autoGenerate = true) val sessionId: Long = 0,
    val taskName: String,
    val startTime: Long,
    val endTime: Long,
    val durationMinutes: Long,
    val completed: Boolean,
    val distractionCount: Int = 0,
    val date: String // ISO yyyy-MM-dd
)
