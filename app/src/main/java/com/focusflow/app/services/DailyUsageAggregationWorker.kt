package com.focusflow.app.services

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.focusflow.app.data.local.database.FocusFlowDatabase
import com.focusflow.app.utils.NotificationHelper
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class DailyUsageAggregationWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            val database = FocusFlowDatabase.getInstance(applicationContext)
            val trackingManager = UsageTrackingManager(applicationContext)

            // Fetch latest today's usage and persist
            val usageList = trackingManager.fetchTodayUsage()
            database.appUsageDao().insertAll(usageList)

            // Check category budgets
            val activeBudgets = database.timeBudgetDao().getActiveBudgets()
            for (budget in activeBudgets) {
                val totalUsed = usageList.filter { it.category == budget.category }.sumOf { it.durationMinutes }
                if (budget.limitMinutes > 0) {
                    val percent = ((totalUsed * 100) / budget.limitMinutes).toInt()
                    val remaining = budget.limitMinutes - totalUsed
                    if (percent >= 75) {
                        NotificationHelper.showBudgetWarning(
                            applicationContext,
                            budget.category,
                            percent,
                            if (remaining > 0) remaining else 0
                        )
                    }
                }
            }

            // Check app-specific limits
            val activeLimits = database.appLimitDao().getActiveLimits()
            for (limit in activeLimits) {
                val appUsage = usageList.find { it.packageName == limit.packageName }
                val used = appUsage?.durationMinutes ?: 0
                if (limit.limitMinutes > 0) {
                    val percent = ((used * 100) / limit.limitMinutes).toInt()
                    val remaining = limit.limitMinutes - used
                    if (percent >= 75) {
                        NotificationHelper.showBudgetWarning(
                            applicationContext,
                            limit.appName,
                            percent,
                            if (remaining > 0) remaining else 0
                        )
                    }
                }
            }

            Result.success()
        } catch (e: Exception) {
            e.printStackTrace()
            Result.retry()
        }
    }
}
