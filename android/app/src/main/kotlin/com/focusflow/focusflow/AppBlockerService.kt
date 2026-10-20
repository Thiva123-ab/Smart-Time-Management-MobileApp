package com.focusflow.focusflow

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import java.util.Calendar

class AppBlockerService : java.lang.Runnable, Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var isRunning = false
    private val checkIntervalMs = 1200L

    companion object {
        const val CHANNEL_ID = "focusflow_blocker_channel"
        const val NOTIFICATION_ID = 1001
        const val PREFS_NAME = "focusflow_limits"

        fun startService(context: Context) {
            val intent = Intent(context, AppBlockerService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, AppBlockerService::class.java)
            context.stopService(intent)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildForegroundNotification())
        isRunning = true
        handler.post(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        handler.removeCallbacks(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun run() {
        if (!isRunning) return

        try {
            checkCurrentForegroundApp()
        } catch (_: Exception) {}

        if (isRunning) {
            handler.postDelayed(this, checkIntervalMs)
        }
    }

    private fun checkCurrentForegroundApp() {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return

        val now = System.currentTimeMillis()
        // Query events in recent 10 seconds to find latest foreground app
        val events = usageStatsManager.queryEvents(now - 10000, now) ?: return
        val event = UsageEvents.Event()
        var currentForegroundPackage: String? = null

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                currentForegroundPackage = event.packageName
            }
        }

        if (currentForegroundPackage == null ||
            currentForegroundPackage == packageName ||
            currentForegroundPackage == "com.android.systemui" ||
            currentForegroundPackage == "android") {
            return
        }

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val limitMinutes = prefs.getInt(currentForegroundPackage, -1)

        if (limitMinutes > 0) {
            // Check today's total usage for this app strictly since 12:00 midnight
            val calendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val startOfDay = calendar.timeInMillis
            val appUsage = getTodayAppUsageMillis(usageStatsManager, currentForegroundPackage, startOfDay, now)
            val usedMinutes = (appUsage / 60000L).toInt()

            if (usedMinutes >= limitMinutes) {
                // Prevent opening / launch lock screen
                val appName = try {
                    val appInfo = packageManager.getApplicationInfo(currentForegroundPackage, 0)
                    packageManager.getApplicationLabel(appInfo).toString()
                } catch (_: Exception) {
                    currentForegroundPackage
                }

                val lockIntent = Intent(this, BlockedAppActivity::class.java).apply {
                    putExtra("blockedPackage", currentForegroundPackage)
                    putExtra("blockedAppName", appName)
                    putExtra("usedMinutes", usedMinutes)
                    putExtra("limitMinutes", limitMinutes)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                startActivity(lockIntent)
            }
        }
    }

    private fun getTodayAppUsageMillis(usageStatsManager: UsageStatsManager, pkg: String, startOfDay: Long, now: Long): Long {
        return try {
            val events = usageStatsManager.queryEvents(startOfDay, now) ?: return 0L
            val event = UsageEvents.Event()
            var totalTime = 0L
            var lastResume: Long? = null
            var handledInitialExit = false
            var hasEvents = false

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.packageName == pkg) {
                    val time = event.timeStamp
                    when (event.eventType) {
                        UsageEvents.Event.ACTIVITY_RESUMED,
                        UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                            hasEvents = true
                            handledInitialExit = true
                            lastResume = time
                        }
                        UsageEvents.Event.ACTIVITY_PAUSED,
                        UsageEvents.Event.MOVE_TO_BACKGROUND,
                        UsageEvents.Event.ACTIVITY_STOPPED -> {
                            hasEvents = true
                            if (lastResume != null) {
                                val s = Math.max(startOfDay, lastResume)
                                val e = Math.min(now, time)
                                if (e > s) {
                                    totalTime += (e - s)
                                }
                                lastResume = null
                            } else if (!handledInitialExit) {
                                handledInitialExit = true
                                val s = startOfDay
                                val e = Math.min(now, time)
                                if (e > s) {
                                    totalTime += (e - s)
                                }
                            }
                        }
                    }
                }
            }

            if (lastResume != null) {
                val s = Math.max(startOfDay, lastResume)
                if (now > s) {
                    totalTime += (now - s)
                }
            }

            // Fallback only if queryEvents yielded zero events for this pkg
            if (!hasEvents) {
                val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startOfDay, now)
                val targetStat = stats?.firstOrNull { it.packageName == pkg && it.lastTimeStamp >= startOfDay }
                if (targetStat != null && targetStat.totalTimeInForeground > 0) {
                    totalTime = targetStat.totalTimeInForeground
                }
            }

            val maxPossible = Math.max(0L, now - startOfDay)
            totalTime.coerceIn(0L, maxPossible)
        } catch (_: Exception) {
            0L
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "FocusFlow App Blocker",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors app usage and enforces daily app limits"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("FocusFlow App Guard Active")
            .setContentText("Enforcing your daily app usage limits")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }
}
