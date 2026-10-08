package com.focusflow.app.data.repository

import com.focusflow.app.data.local.dao.AppUsageDao
import com.focusflow.app.data.local.dao.CategoryUsageSummary
import com.focusflow.app.data.local.entities.AppUsageEntity
import kotlinx.coroutines.flow.Flow
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AppUsageRepository(private val appUsageDao: AppUsageDao) {

    fun getTodayDate(): String {
        return SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
    }

    fun getUsageForDate(date: String = getTodayDate()): Flow<List<AppUsageEntity>> {
        return appUsageDao.getUsageForDate(date)
    }

    fun getTopAppsForDate(date: String = getTodayDate(), limit: Int = 5): Flow<List<AppUsageEntity>> {
        return appUsageDao.getTopAppsForDate(date, limit)
    }

    fun getTotalDurationForDate(date: String = getTodayDate()): Flow<Long?> {
        return appUsageDao.getTotalDurationForDate(date)
    }

    fun getCategorySummariesForDate(date: String = getTodayDate()): Flow<List<CategoryUsageSummary>> {
        return appUsageDao.getCategorySummariesForDate(date)
    }

    fun getUsageBetweenDates(startDate: String, endDate: String): Flow<List<AppUsageEntity>> {
        return appUsageDao.getUsageBetweenDates(startDate, endDate)
    }

    suspend fun saveAppUsageList(usages: List<AppUsageEntity>) {
        appUsageDao.insertAll(usages)
    }

    suspend fun saveAppUsage(usage: AppUsageEntity): Long {
        return appUsageDao.insertOrUpdate(usage)
    }

    suspend fun clearTodayUsage(date: String = getTodayDate()) {
        appUsageDao.deleteUsageForDate(date)
    }

    suspend fun clearAllData() {
        appUsageDao.deleteAllUsage()
    }
}
