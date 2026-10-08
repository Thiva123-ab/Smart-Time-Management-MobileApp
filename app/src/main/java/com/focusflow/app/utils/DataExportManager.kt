package com.focusflow.app.utils

import com.focusflow.app.data.local.entities.AppUsageEntity
import com.google.gson.GsonBuilder

object DataExportManager {

    private val gson = GsonBuilder().setPrettyPrinting().create()

    /**
     * Converts a list of AppUsageEntity records into a CSV string.
     * Header: date,app,category,duration_minutes,launch_count
     */
    fun exportToCsv(usages: List<AppUsageEntity>): String {
        val sb = StringBuilder()
        sb.append("date,app,category,duration_minutes,launch_count\n")
        for (item in usages) {
            sb.append("${item.date},\"${item.appName}\",\"${item.category}\",${item.durationMinutes},${item.launchCount}\n")
        }
        return sb.toString()
    }

    /**
     * Converts a list of AppUsageEntity records into a formatted JSON string.
     */
    fun exportToJson(usages: List<AppUsageEntity>): String {
        return gson.toJson(usages)
    }
}
