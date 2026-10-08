package com.focusflow.app.data.local.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "achievements")
data class AchievementEntity(
    @PrimaryKey val achievementId: String, // e.g. "first_focus", "streak_3_days"
    val title: String,
    val description: String,
    val unlockedDate: Long? = null, // null if not yet unlocked
    val isUnlocked: Boolean = false,
    val category: String = "GENERAL" // FOCUS, STREAK, GOALS, DIGITAL_BALANCE
)
