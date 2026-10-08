package com.focusflow.app.data.local.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "goals")
data class GoalEntity(
    @PrimaryKey(autoGenerate = true) val goalId: Long = 0,
    val title: String,
    val category: String, // Study, Coding, Reading, Exercise, Work, etc.
    val targetMinutes: Long,
    val completedMinutes: Long = 0,
    val date: String, // ISO yyyy-MM-dd
    val status: String = "IN_PROGRESS" // IN_PROGRESS, COMPLETED, FAILED
)
