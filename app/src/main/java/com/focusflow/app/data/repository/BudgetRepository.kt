package com.focusflow.app.data.repository

import com.focusflow.app.data.local.dao.AppLimitDao
import com.focusflow.app.data.local.dao.TimeBudgetDao
import com.focusflow.app.data.local.entities.AppLimitEntity
import com.focusflow.app.data.local.entities.TimeBudgetEntity
import kotlinx.coroutines.flow.Flow

class BudgetRepository(
    private val timeBudgetDao: TimeBudgetDao,
    private val appLimitDao: AppLimitDao
) {
    fun getAllBudgets(): Flow<List<TimeBudgetEntity>> = timeBudgetDao.getAllBudgets()

    fun getBudgetForCategory(category: String): Flow<TimeBudgetEntity?> =
        timeBudgetDao.getBudgetForCategory(category)

    suspend fun setCategoryBudget(category: String, limitMinutes: Long, enabled: Boolean = true) {
        val budget = TimeBudgetEntity(
            category = category,
            limitMinutes = limitMinutes,
            date = "daily_default",
            enabled = enabled
        )
        timeBudgetDao.insertOrUpdate(budget)
    }

    suspend fun deleteBudget(budgetId: Long) {
        timeBudgetDao.deleteBudget(budgetId)
    }

    fun getAllAppLimits(): Flow<List<AppLimitEntity>> = appLimitDao.getAllLimits()

    fun getLimitForPackage(packageName: String): Flow<AppLimitEntity?> =
        appLimitDao.getLimitForPackage(packageName)

    suspend fun setAppLimit(packageName: String, appName: String, limitMinutes: Long, enabled: Boolean = true) {
        val limit = AppLimitEntity(
            packageName = packageName,
            appName = appName,
            limitMinutes = limitMinutes,
            date = "daily_default",
            enabled = enabled
        )
        appLimitDao.insertOrUpdate(limit)
    }

    suspend fun deleteAppLimit(limitId: Long) {
        appLimitDao.deleteLimit(limitId)
    }
}
