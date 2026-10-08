package com.focusflow.app.data.local.entities

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "app_usage",
    indices = [
        Index(value = ["date", "packageName"], unique = true),
        Index(value = ["date"]),
        Index(value = ["category"])
    ]
)
data class AppUsageEntity(
    @PrimaryKey(autoGenerate = true) val usageId: Long = 0,
    val packageName: String,
    val appName: String,
    val category: String, // Education, Work, Social Media, Entertainment, Communication, Gaming, Browser, Productivity, Other
    val startTime: Long,
    val endTime: Long,
    val durationMinutes: Long,
    val date: String, // ISO yyyy-MM-dd
    val launchCount: Int = 0
)
