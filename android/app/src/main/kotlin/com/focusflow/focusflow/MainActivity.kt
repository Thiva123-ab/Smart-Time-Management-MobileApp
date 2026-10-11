package com.focusflow.focusflow

import android.app.AppOpsManager
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
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.focusflow.app/usage"

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
                else -> {
                    result.notImplemented()
                }
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

        val aggregated = mutableMapOf<String, Long>()

        // 1. Try aggregated stats query for exact timestamp range
        val aggregatedStats = try {
            usageStatsManager.queryAndAggregateUsageStats(startTime, endTime)
        } catch (_: Exception) {
            emptyMap<String, UsageStats>()
        }

        if (aggregatedStats.isNotEmpty()) {
            for ((pkg, stat) in aggregatedStats) {
                val time = stat.totalTimeInForeground
                if (time > 0) {
                    aggregated[pkg] = time
                }
            }
        }

        // 2. Fallback to interval query if aggregated map was empty
        if (aggregated.isEmpty()) {
            val usageStatsList: List<UsageStats> = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                startTime,
                endTime
            ) ?: emptyList()

            for (stat in usageStatsList) {
                val pkg = stat.packageName ?: continue
                val time = stat.totalTimeInForeground
                if (time > 0) {
                    aggregated[pkg] = (aggregated[pkg] ?: 0L) + time
                }
            }
        }

        val pm = packageManager
        val resultList = mutableListOf<Map<String, Any>>()

        for ((pkg, timeMillis) in aggregated) {
            val durationMinutes = (timeMillis / 60000L).toInt()
            if (durationMinutes <= 0) continue

            // Filter out system framework package
            if (pkg == "android" || pkg == packageName) continue

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
                "launchCount" to 1
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
