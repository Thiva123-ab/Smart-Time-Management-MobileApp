package com.focusflow.app.data.repository

import com.focusflow.app.data.local.dao.DailyScoreDao
import com.focusflow.app.data.local.entities.DailyScoreEntity
import kotlinx.coroutines.flow.Flow
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class AnalyticsRepository(private val dailyScoreDao: DailyScoreDao) {

    private fun getTodayDate(): String {
        return SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
    }

    fun getScoreForDate(date: String = getTodayDate()): Flow<DailyScoreEntity?> =
        dailyScoreDao.getScoreForDate(date)

    suspend fun getScoreForDateSync(date: String = getTodayDate()): DailyScoreEntity? =
        dailyScoreDao.getScoreForDateSync(date)

    fun getRecentScores(limit: Int = 30): Flow<List<DailyScoreEntity>> =
        dailyScoreDao.getRecentScores(limit)

    suspend fun recordDailyScore(score: DailyScoreEntity) {
        dailyScoreDao.insertOrUpdate(score)
    }

    fun getWeeklyDates(): Pair<String, String> {
        val calendar = Calendar.getInstance()
        val end = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(calendar.time)
        calendar.add(Calendar.DAY_OF_YEAR, -6)
        val start = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(calendar.time)
        return Pair(start, end)
    }

    fun getWeeklyAverageScore(): Flow<Double?> {
        val (start, end) = getWeeklyDates()
        return dailyScoreDao.getAverageScoreBetweenDates(start, end)
    }
}
