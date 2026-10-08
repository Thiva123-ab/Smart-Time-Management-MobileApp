package com.focusflow.app.data.local.entities

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "app_limits",
    indices = [Index(value = ["packageName", "date"], unique = true)]
)
data class AppLimitEntity(
    @PrimaryKey(autoGenerate = true) val limitId: Long = 0,
    val packageName: String,
    val appName: String,
    val limitMinutes: Long,
    val date: String, // ISO yyyy-MM-dd or "daily_default"
    val enabled: Boolean = true
)
