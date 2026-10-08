package com.focusflow.app.data.local.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "pomodoro_sessions")
data class PomodoroEntity(
    @PrimaryKey(autoGenerate = true) val pomodoroId: Long = 0,
    val focusMinutes: Int,
    val breakMinutes: Int,
    val startTime: Long,
    val endTime: Long,
    val completed: Boolean,
    val date: String // ISO yyyy-MM-dd
)
