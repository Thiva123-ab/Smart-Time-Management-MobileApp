package com.focusflow.focusflow

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase

class ScheduleAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 100)
        val blockId = intent.getIntExtra("blockId", id / 100)
        val title = intent.getStringExtra("title") ?: "FocusFlow Task"
        val body = intent.getStringExtra("body") ?: ""
        val subText = intent.getStringExtra("subText") ?: "Schedule"

        // Double verification: verify if this task actually still exists in database and is not completed
        if (blockId > 0) {
            val dbFile = context.getDatabasePath("focusflow_flutter.db")
            if (dbFile.exists()) {
                var isActive = false
                try {
                    val db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)
                    val cursor = db.rawQuery("SELECT isCompleted FROM time_blocks WHERE id = ?", arrayOf(blockId.toString()))
                    if (cursor.moveToFirst()) {
                        val isCompleted = cursor.getInt(0)
                        isActive = (isCompleted == 0)
                    }
                    cursor.close()
                    db.close()
                } catch (_: Exception) {
                    isActive = true
                }

                if (!isActive) {
                    // Task was deleted or marked completed! Do NOT show notification.
                    return
                }
            }
        }

        TaskNotificationManager.showNotification(context, id, title, body, subText)
    }
}

