package com.focusflow.focusflow

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.focusflow.app/usage"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        TaskNotificationManager.initChannel(this)
        requestNotificationPermission()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsagePermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "openUsageSettings" -> {
                    openUsageSettings()
                    result.success(true)
                }
                "getUsageStats" -> {
                    val startTime = call.argument<Long>("startTime") ?: 0L
                    val endTime = call.argument<Long>("endTime") ?: System.currentTimeMillis()
                    val stats = getAppUsageStats(startTime, endTime)
                    result.success(stats)
                }
                "getAppIcon" -> {
                    val pkg = call.argument<String>("packageName") ?: ""
                    val iconBytes = if (pkg.isNotEmpty()) getAppIconBytes(packageManager, pkg) else null
                    result.success(iconBytes)
                }
                "hasOverlayPermission" -> {
                    val hasPerm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(hasPerm)
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            android.net.Uri.parse("package:$packageName")
                        ).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "updateAppLimits" -> {
                    val limits = call.argument<Map<String, Int>>("limits") ?: emptyMap()
                    val prefs = getSharedPreferences(AppBlockerService.PREFS_NAME, Context.MODE_PRIVATE)
                    val editor = prefs.edit()
                    editor.clear()
                    for ((pkg, limit) in limits) {
                        editor.putInt(pkg, limit)
                    }
                    editor.apply()

                    // If limits exist and usage permission is granted, ensure blocker service is running
                    if (limits.isNotEmpty() && hasUsageStatsPermission()) {
                        try {
                            AppBlockerService.startService(this)
                        } catch (_: Exception) {}
                    } else if (limits.isEmpty()) {
                        try {
                            AppBlockerService.stopService(this)
                        } catch (_: Exception) {}
                    }
                    result.success(true)
                }
                "startBlockerService" -> {
                    if (hasUsageStatsPermission()) {
                        try {
                            AppBlockerService.startService(this)
                        } catch (_: Exception) {}
                    }
                    result.success(true)
                }
                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: 101
                    val title = call.argument<String>("title") ?: "FocusFlow"
                    val body = call.argument<String>("body") ?: ""
                    val subText = call.argument<String>("subText") ?: "Schedule"
                    TaskNotificationManager.showNotification(this, id, title, body, subText)
                    result.success(true)
                }
                "hasNotificationPermission" -> {
                    result.success(hasNotificationPermission())
                }
                "requestNotificationPermission" -> {
                    requestNotificationPermission()
                    result.success(true)
                }
                "scheduleAlarm" -> {
                    val id = call.argument<Int>("id") ?: 100
                    val timeMillis = (call.argument<Number>("timeMillis"))?.toLong() ?: 0L
                    val title = call.argument<String>("title") ?: "FocusFlow"
                    val body = call.argument<String>("body") ?: ""
                    val subText = call.argument<String>("subText") ?: "Schedule"
                    TaskNotificationManager.scheduleAlarm(this, id, timeMillis, title, body, subText)
                    result.success(true)
                }
                "cancelAlarm" -> {
                    val id = call.argument<Int>("id") ?: 100
                    TaskNotificationManager.cancelAlarm(this, id)
                    result.success(true)
                }
                "cancelTaskAlarms" -> {
                    val blockId = call.argument<Int>("blockId") ?: 0
                    if (blockId > 0) {
                        TaskNotificationManager.cancelAllForTask(this, blockId)
                    }
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            NotificationManagerCompat.from(this).areNotificationsEnabled()
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1002)
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageSettings() {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        } catch (_: Exception) {
            try {
                val fallbackIntent = Intent(Settings.ACTION_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(fallbackIntent)
            } catch (_: Exception) {}
        }
    }

    private fun getAppIconBytes(pm: PackageManager, pkg: String): ByteArray? {
        return try {
            val drawable: Drawable = try {
                val appInfo = pm.getApplicationInfo(pkg, 0)
                appInfo.loadIcon(pm) ?: pm.getApplicationIcon(pkg)
            } catch (_: Exception) {
                pm.getApplicationIcon(pkg)
            }

            val intrinsicW = drawable.intrinsicWidth
            val intrinsicH = drawable.intrinsicHeight
            val width = if (intrinsicW > 0) intrinsicW else 108
            val height = if (intrinsicH > 0) intrinsicH else 108

            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)

            val scaled = Bitmap.createScaledBitmap(bitmap, 72, 72, true)
            val outputStream = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.PNG, 90, outputStream)
            outputStream.toByteArray()
        } catch (_: Exception) {
            null
        }
    }

    private fun getAppUsageStats(startTime: Long, endTime: Long): List<Map<String, Any>> {
        if (!hasUsageStatsPermission()) {
            return emptyList()
        }

        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyList()

        val foregroundTimeMap = mutableMapOf<String, Long>()
        val launchCountMap = mutableMapOf<String, Int>()

        val now = System.currentTimeMillis()
        val effectiveEnd = Math.min(endTime, now)
        val maxPossibleDuration = Math.max(0L, effectiveEnd - startTime).coerceAtMost(86400000L) // Max 24 hours (1440 minutes)

        // 1. Precise Event-Based Usage (strictly calculates time spent between startTime and effectiveEnd)
        var hasValidEvents = false
        try {
            val events = usageStatsManager.queryEvents(startTime, effectiveEnd)
            if (events != null) {
                val startTimes = mutableMapOf<String, Long>()
                val handledInitialExit = mutableSetOf<String>()
                val event = UsageEvents.Event()

                while (events.hasNextEvent()) {
                    events.getNextEvent(event)
                    val pkg = event.packageName ?: continue
                    val time = event.timeStamp

                    if (pkg == "android" || pkg == packageName || pkg == "com.android.systemui") continue

                    when (event.eventType) {
                        UsageEvents.Event.ACTIVITY_RESUMED,
                        UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                            hasValidEvents = true
                            handledInitialExit.add(pkg)
                            startTimes[pkg] = time
                            launchCountMap[pkg] = (launchCountMap[pkg] ?: 0) + 1
                        }
                        UsageEvents.Event.ACTIVITY_PAUSED,
                        UsageEvents.Event.MOVE_TO_BACKGROUND,
                        UsageEvents.Event.ACTIVITY_STOPPED -> {
                            hasValidEvents = true
                            val resumedTime = startTimes.remove(pkg)
                            if (resumedTime != null) {
                                val sessionStart = Math.max(startTime, resumedTime)
                                val sessionEnd = Math.min(effectiveEnd, time)
                                if (sessionEnd > sessionStart) {
                                    val sessionDuration = sessionEnd - sessionStart
                                    foregroundTimeMap[pkg] = (foregroundTimeMap[pkg] ?: 0L) + sessionDuration
                                }
                            } else if (!handledInitialExit.contains(pkg)) {
                                // App was already open before midnight (startTime). Count from startTime to first exit only once.
                                handledInitialExit.add(pkg)
                                val sessionStart = startTime
                                val sessionEnd = Math.min(effectiveEnd, time)
                                if (sessionEnd > sessionStart) {
                                    val sessionDuration = sessionEnd - sessionStart
                                    foregroundTimeMap[pkg] = (foregroundTimeMap[pkg] ?: 0L) + sessionDuration
                                }
                            }
                            // Ignore subsequent duplicate PAUSED/BACKGROUND events for the same exit!
                        }
                    }
                }

                // Any app currently still open in the foreground at query time
                for ((pkg, resumedTime) in startTimes) {
                    val sessionStart = Math.max(startTime, resumedTime)
                    if (effectiveEnd > sessionStart) {
                        val sessionDuration = effectiveEnd - sessionStart
                        foregroundTimeMap[pkg] = (foregroundTimeMap[pkg] ?: 0L) + sessionDuration
                    }
                }
            }
        } catch (_: Exception) {}

        // 2. Fallback: if queryEvents yielded zero events, query INTERVAL_DAILY stats that were active today (lastTimeStamp >= startTime)
        if (!hasValidEvents) {
            val dailyStats = try {
                usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, effectiveEnd)
            } catch (_: Exception) {
                emptyList<UsageStats>()
            }

            if (dailyStats != null && dailyStats.isNotEmpty()) {
                for (stat in dailyStats) {
                    val pkg = stat.packageName ?: continue
                    if (pkg == "android" || pkg == packageName || pkg == "com.android.systemui") continue
                    if (stat.lastTimeStamp >= startTime && stat.totalTimeInForeground > 0) {
                        val boundedDuration = Math.min(stat.totalTimeInForeground, maxPossibleDuration)
                        if (boundedDuration > (foregroundTimeMap[pkg] ?: 0L)) {
                            foregroundTimeMap[pkg] = boundedDuration
                        }
                    }
                }
            }
        }

        val pm = packageManager
        val resultList = mutableListOf<Map<String, Any>>()
        val maxPossibleMinutes = (maxPossibleDuration / 60000L).toInt().coerceIn(1, 1440)

        for ((pkg, timeMillis) in foregroundTimeMap) {
            var durationMinutes = (timeMillis / 60000L).toInt()
            // Strictly enforce that no app exceeds the total elapsed time of today (max 24 hours / 1440 mins)
            if (durationMinutes > maxPossibleMinutes) {
                durationMinutes = maxPossibleMinutes
            }
            if (durationMinutes <= 0) continue

            // Filter out system packages
            if (pkg == "android" || pkg == packageName || pkg == "com.android.systemui") continue

            var appName: String? = null
            try {
                val appInfo = pm.getApplicationInfo(pkg, 0)
                val label = pm.getApplicationLabel(appInfo).toString()
                if (label.isNotBlank() && label != pkg) {
                    appName = label
                }
            } catch (_: Exception) {}

            if (appName == null || appName.equals("katana", ignoreCase = true)) {
                val knownNames = mapOf(
                    "com.facebook.katana" to "Facebook",
                    "com.facebook.orca" to "Messenger",
                    "com.whatsapp" to "WhatsApp",
                    "com.google.android.youtube" to "YouTube",
                    "com.instagram.android" to "Instagram",
                    "com.android.chrome" to "Chrome",
                    "com.google.android.apps.messaging" to "Messages",
                    "com.zhiliaoapp.musically" to "TikTok",
                    "org.telegram.messenger" to "Telegram",
                    "com.twitter.android" to "X (Twitter)"
                )
                appName = knownNames[pkg] ?: run {
                    val segments = pkg.split(".")
                    if (segments.isNotEmpty()) {
                        segments.last().replaceFirstChar { it.uppercase() }
                    } else pkg
                }
            }

            val appMap = mutableMapOf<String, Any>(
                "packageName" to pkg,
                "appName" to appName,
                "durationMinutes" to durationMinutes,
                "launchCount" to (launchCountMap[pkg] ?: 1)
            )

            // Attach app icon byte array
            val iconBytes = getAppIconBytes(pm, pkg)
            if (iconBytes != null) {
                appMap["appIcon"] = iconBytes
            }

            resultList.add(appMap)
        }

        // Sort descending by duration
        resultList.sortByDescending { (it["durationMinutes"] as? Int) ?: 0 }
        return resultList
    }
}
