package com.focusflow.focusflow

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class FocusFlowWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH_WIDGET || intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            updateAllWidgets(context)
        }
    }

    companion object {
        const val PREFS_NAME = "focusflow_widget_prefs"
        const val KEY_SCORE = "widget_score"
        const val KEY_GRADE = "widget_grade"
        const val KEY_FOCUS_MINS = "widget_focus_mins"
        const val KEY_STREAK_DAYS = "widget_streak_days"
        const val KEY_TASKS_DONE = "widget_tasks_done"
        const val KEY_IS_FOCUSING = "widget_is_focusing"
        const val KEY_LAST_SYNC = "widget_last_sync"

        const val ACTION_REFRESH_WIDGET = "com.focusflow.app.REFRESH_WIDGET"
        const val EXTRA_WIDGET_ACTION = "widget_action"
        const val ACTION_START_FOCUS = "start_focus"

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            val score = prefs.getInt(KEY_SCORE, 85)
            val grade = prefs.getString(KEY_GRADE, "GRADE A") ?: "GRADE A"
            val focusMins = prefs.getInt(KEY_FOCUS_MINS, 0)
            val streakDays = prefs.getInt(KEY_STREAK_DAYS, 1)
            val tasksDone = prefs.getInt(KEY_TASKS_DONE, 0)
            val isFocusing = prefs.getBoolean(KEY_IS_FOCUSING, false)
            val lastSync = prefs.getString(KEY_LAST_SYNC, "") ?: ""

            val views = RemoteViews(context.packageName, R.layout.focusflow_widget_layout)

            // 1. Header & Status
            val timeFormat = SimpleDateFormat("h:mm a", Locale.getDefault())
            val formattedTime = if (lastSync.isNotEmpty()) lastSync else timeFormat.format(Date())
            views.setTextViewText(R.id.widget_status, if (isFocusing) "⚡ Focusing..." else formattedTime)

            // 2. Score Badge
            views.setTextViewText(R.id.widget_score_value, "$score%")
            views.setTextViewText(R.id.widget_score_grade, grade.uppercase(Locale.getDefault()))

            // 3. Deep Focus Hours / Minutes
            val focusHours = (focusMins / 60.0)
            val focusText = if (focusMins >= 60) {
                String.format(Locale.getDefault(), "🎯 Deep Focus: %.1fh (%dm)", focusHours, focusMins)
            } else {
                "🎯 Deep Focus: ${focusMins}m"
            }
            views.setTextViewText(R.id.widget_focus_time, focusText)

            // 4. Streak
            val streakText = "🔥 Streak: $streakDays Day${if (streakDays == 1) "" else "s"} Active"
            views.setTextViewText(R.id.widget_streak, streakText)

            // 5. Tasks Done
            val tasksText = "✓ $tasksDone Target${if (tasksDone == 1) "" else "s"} & Tasks Done"
            views.setTextViewText(R.id.widget_tasks_done, tasksText)

            // 6. PendingIntent: Refresh Button
            val refreshIntent = Intent(context, FocusFlowWidgetProvider::class.java).apply {
                action = ACTION_REFRESH_WIDGET
            }
            val refreshPendingIntent = PendingIntent.getBroadcast(
                context,
                2001,
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )
            views.setOnClickPendingIntent(R.id.widget_btn_refresh, refreshPendingIntent)

            // 7. PendingIntent: Start Focus CTA (launches directly into focus timer)
            val startFocusIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(EXTRA_WIDGET_ACTION, ACTION_START_FOCUS)
            }
            val startFocusPendingIntent = PendingIntent.getActivity(
                context,
                2002,
                startFocusIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )
            views.setOnClickPendingIntent(R.id.widget_btn_focus, startFocusPendingIntent)

            // 8. PendingIntent: Open App (whole card / open button)
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                2003,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )
            views.setOnClickPendingIntent(R.id.widget_btn_open, openAppPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_root, openAppPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, FocusFlowWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            for (id in appWidgetIds) {
                updateWidget(context, appWidgetManager, id)
            }
        }
    }
}
