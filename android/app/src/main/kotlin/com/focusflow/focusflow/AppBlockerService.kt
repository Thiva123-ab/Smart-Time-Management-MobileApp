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
            // Check today's total usage for this app
            val calendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val startOfDay = calendar.timeInMillis
            val statsMap = usageStatsManager.queryAndAggregateUsageStats(startOfDay, now)
            val appUsage = statsMap[currentForegroundPackage]?.totalTimeInForeground ?: 0L
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
