package com.focusflow.app.domain.usecase

import com.focusflow.app.data.local.entities.AppLimitEntity
import com.focusflow.app.data.local.entities.AppUsageEntity
import com.focusflow.app.data.local.entities.TimeBudgetEntity
import com.focusflow.app.data.repository.AppUsageRepository
import com.focusflow.app.data.repository.BudgetRepository
import kotlinx.coroutines.flow.firstOrNull

data class BudgetStatus(
    val category: String,
    val limitMinutes: Long,
    val usedMinutes: Long,
    val percentUsed: Int,
    val isExceeded: Boolean
)

data class AppLimitStatus(
    val packageName: String,
    val appName: String,
    val limitMinutes: Long,
    val usedMinutes: Long,
    val percentUsed: Int,
    val isExceeded: Boolean
)

class EvaluateBudgetsUseCase(
    private val budgetRepository: BudgetRepository,
    private val appUsageRepository: AppUsageRepository
) {
    suspend fun getCategoryBudgetStatuses(date: String = appUsageRepository.getTodayDate()): List<BudgetStatus> {
        val budgets = budgetRepository.getAllBudgets().firstOrNull() ?: emptyList()
        val usages = appUsageRepository.getUsageForDate(date).firstOrNull() ?: emptyList()

        return budgets.map { budget ->
            val used = usages.filter { it.category == budget.category }.sumOf { it.durationMinutes }
            val percent = if (budget.limitMinutes > 0) ((used * 100) / budget.limitMinutes).toInt() else 0
            BudgetStatus(
                category = budget.category,
                limitMinutes = budget.limitMinutes,
                usedMinutes = used,
                percentUsed = percent,
                isExceeded = used >= budget.limitMinutes
            )
        }
    }

    suspend fun getAppLimitStatuses(date: String = appUsageRepository.getTodayDate()): List<AppLimitStatus> {
        val limits = budgetRepository.getAllAppLimits().firstOrNull() ?: emptyList()
        val usages = appUsageRepository.getUsageForDate(date).firstOrNull() ?: emptyList()

        return limits.map { limit ->
            val appUsage = usages.find { it.packageName == limit.packageName }
            val used = appUsage?.durationMinutes ?: 0
            val percent = if (limit.limitMinutes > 0) ((used * 100) / limit.limitMinutes).toInt() else 0
            AppLimitStatus(
                packageName = limit.packageName,
                appName = limit.appName,
                limitMinutes = limit.limitMinutes,
                usedMinutes = used,
                percentUsed = percent,
                isExceeded = used >= limit.limitMinutes
            )
        }
    }
}
