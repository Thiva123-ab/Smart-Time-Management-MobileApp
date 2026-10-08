package com.focusflow.app.utils

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.focusflow.app.FocusFlowApplication
import com.focusflow.app.MainActivity
import com.focusflow.app.R

object NotificationHelper {

    fun showBudgetWarning(context: Context, entityName: String, percentUsed: Int, remainingMinutes: Long) {
        if (!PermissionHelper.hasNotificationPermission(context)) return

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            entityName.hashCode(),
            intent,
            PendingIntent.FLAG_IMMUTABLE
        )

        val title = when {
            percentUsed >= 100 -> "⚠️ Daily Limit Reached: $entityName"
            percentUsed >= 90 -> "🚨 90% Limit Reached: $entityName"
            else -> "⏳ 75% Budget Used: $entityName"
        }

        val body = if (remainingMinutes > 0) {
            "You have $remainingMinutes minutes left for $entityName today."
        } else {
            "You have reached your daily limit for $entityName. Time to switch to something productive!"
        }

        val notification = NotificationCompat.Builder(context, FocusFlowApplication.CHANNEL_BUDGET_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(entityName.hashCode(), notification)
    }

    fun showFocusComplete(context: Context, taskName: String, durationMinutes: Long, distractions: Int) {
        if (!PermissionHelper.hasNotificationPermission(context)) return

        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            1001,
            intent,
            PendingIntent.FLAG_IMMUTABLE
        )

        val body = "You completed $durationMinutes minutes on '$taskName' with $distractions distractions. Great job!"

        val notification = NotificationCompat.Builder(context, FocusFlowApplication.CHANNEL_FOCUS_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("🎉 Focus Session Completed!")
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(1001, notification)
    }

    fun showGoalReminder(context: Context, goalTitle: String, completedMinutes: Long, targetMinutes: Long) {
        if (!PermissionHelper.hasNotificationPermission(context)) return

        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            goalTitle.hashCode(),
            intent,
            PendingIntent.FLAG_IMMUTABLE
        )

        val body = "You planned $targetMinutes min for '$goalTitle' today. Current progress: $completedMinutes min."

        val notification = NotificationCompat.Builder(context, FocusFlowApplication.CHANNEL_GOALS_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("🎯 Goal Reminder")
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(goalTitle.hashCode(), notification)
    }
}
