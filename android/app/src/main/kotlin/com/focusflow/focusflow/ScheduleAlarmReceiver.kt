package com.focusflow.focusflow

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ScheduleAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 100)
        val title = intent.getStringExtra("title") ?: "FocusFlow Task"
        val body = intent.getStringExtra("body") ?: ""
        val subText = intent.getStringExtra("subText") ?: "Schedule"
        TaskNotificationManager.showNotification(context, id, title, body, subText)
    }
}
