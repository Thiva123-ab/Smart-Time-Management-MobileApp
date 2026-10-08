package com.focusflow.app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class FocusFlowApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        scheduleUsageWork()
    }

    private fun scheduleUsageWork() {
        val workRequest = androidx.work.PeriodicWorkRequestBuilder<com.focusflow.app.services.DailyUsageAggregationWorker>(
            1, java.util.concurrent.TimeUnit.HOURS
        ).build()
        androidx.work.WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "DailyUsageAggregation",
            androidx.work.ExistingPeriodicWorkPolicy.KEEP,
            workRequest
        )
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NotificationManager::class.java)

            val budgetChannel = NotificationChannel(
                CHANNEL_BUDGET_ID,
                getString(R.string.notification_channel_budget),
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = getString(R.string.notification_channel_budget_desc)
                enableVibration(true)
            }

            val focusChannel = NotificationChannel(
                CHANNEL_FOCUS_ID,
                getString(R.string.notification_channel_focus),
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = getString(R.string.notification_channel_focus_desc)
            }

            val goalsChannel = NotificationChannel(
                CHANNEL_GOALS_ID,
                getString(R.string.notification_channel_goals),
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = getString(R.string.notification_channel_goals_desc)
            }

            notificationManager?.createNotificationChannels(
                listOf(budgetChannel, focusChannel, goalsChannel)
            )
        }
    }

    companion object {
        const val CHANNEL_BUDGET_ID = "focusflow_budget_alerts"
        const val CHANNEL_FOCUS_ID = "focusflow_focus_sessions"
        const val CHANNEL_GOALS_ID = "focusflow_goals_streaks"
    }
}
