package com.focusflow.app.services

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import com.focusflow.app.data.local.entities.AppUsageEntity
import com.focusflow.app.domain.AppCategoryManager
import com.focusflow.app.utils.PermissionHelper
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class UsageTrackingManager(private val context: Context) {

    private val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
    private val packageManager = context.packageManager

    private fun getTodayDate(): String {
        return SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
    }

    private fun getTodayStartMillis(): Long {
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        return calendar.timeInMillis
    }

    fun fetchTodayUsage(userCustomMap: Map<String, String> = emptyMap()): List<AppUsageEntity> {
        val todayStr = getTodayDate()
        val startTime = getTodayStartMillis()
        val endTime = System.currentTimeMillis()

        if (!PermissionHelper.hasUsageStatsPermission(context) || usageStatsManager == null) {
            // Return sensible default demo data if permissions not yet granted
            return getDemoUsageData(todayStr, startTime, endTime)
        }

        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()

        val foregroundTimes = mutableMapOf<String, Long>()
        val launchCounts = mutableMapOf<String, Int>()
        val lastEventTimestamps = mutableMapOf<String, Long>()

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            val pkg = event.packageName

            // Skip internal android system services
            if (pkg == "android" || pkg == context.packageName) continue

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    lastEventTimestamps[pkg] = event.timeStamp
                    launchCounts[pkg] = (launchCounts[pkg] ?: 0) + 1
                }
                UsageEvents.Event.ACTIVITY_PAUSED -> {
                    val lastResume = lastEventTimestamps[pkg]
                    if (lastResume != null) {
                        val duration = event.timeStamp - lastResume
                        foregroundTimes[pkg] = (foregroundTimes[pkg] ?: 0L) + duration
                        lastEventTimestamps.remove(pkg)
                    }
                }
            }
        }

        // Account for any app currently in foreground
        for ((pkg, lastResume) in lastEventTimestamps) {
            val duration = endTime - lastResume
            foregroundTimes[pkg] = (foregroundTimes[pkg] ?: 0L) + duration
        }

        // Convert to AppUsageEntity list
        val result = mutableListOf<AppUsageEntity>()
        for ((pkg, totalMillis) in foregroundTimes) {
            val durationMinutes = totalMillis / (1000 * 60)
            if (durationMinutes < 1) continue // Skip micro-glances (< 1 min)

            val appName = try {
                val appInfo = packageManager.getApplicationInfo(pkg, 0)
                packageManager.getApplicationLabel(appInfo).toString()
            } catch (e: PackageManager.NameNotFoundException) {
                pkg.substringAfterLast('.')
            }

            val category = AppCategoryManager.getCategoryForPackage(pkg, userCustomMap)
            val launches = launchCounts[pkg] ?: 1

            result.add(
                AppUsageEntity(
                    packageName = pkg,
                    appName = appName,
                    category = category,
                    startTime = startTime,
                    endTime = endTime,
                    durationMinutes = durationMinutes,
                    date = todayStr,
                    launchCount = launches
                )
            )
        }

        return if (result.isEmpty()) {
            getDemoUsageData(todayStr, startTime, endTime)
        } else {
            result.sortedByDescending { it.durationMinutes }
        }
    }

    private fun getDemoUsageData(date: String, start: Long, end: Long): List<AppUsageEntity> {
        return listOf(
            AppUsageEntity(0, "com.google.android.youtube", "YouTube", AppCategoryManager.CATEGORY_ENTERTAINMENT, start, end, 85, date, 12),
            AppUsageEntity(0, "com.instagram.android", "Instagram", AppCategoryManager.CATEGORY_SOCIAL, start, end, 45, date, 18),
            AppUsageEntity(0, "com.whatsapp", "WhatsApp", AppCategoryManager.CATEGORY_COMMUNICATION, start, end, 35, date, 24),
            AppUsageEntity(0, "com.android.chrome", "Chrome", AppCategoryManager.CATEGORY_BROWSER, start, end, 30, date, 9),
            AppUsageEntity(0, "notion.id", "Notion", AppCategoryManager.CATEGORY_PRODUCTIVITY, start, end, 55, date, 6),
            AppUsageEntity(0, "org.coursera.android", "Coursera", AppCategoryManager.CATEGORY_EDUCATION, start, end, 65, date, 3),
            AppUsageEntity(0, "com.slack", "Slack", AppCategoryManager.CATEGORY_WORK, start, end, 40, date, 15)
        )
    }
}
