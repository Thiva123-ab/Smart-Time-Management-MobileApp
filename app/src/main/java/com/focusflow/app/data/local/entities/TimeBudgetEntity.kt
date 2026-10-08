package com.focusflow.app.data.local.entities

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "time_budgets",
    indices = [Index(value = ["category", "date"], unique = true)]
)
data class TimeBudgetEntity(
    @PrimaryKey(autoGenerate = true) val budgetId: Long = 0,
    val category: String,
    val limitMinutes: Long,
    val date: String, // ISO yyyy-MM-dd or "daily_default"
    val enabled: Boolean = true
)
