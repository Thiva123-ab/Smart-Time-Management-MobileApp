package com.focusflow.app.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.focusflow.app.data.local.entities.AppUsageEntity
import kotlinx.coroutines.flow.Flow

data class CategoryUsageSummary(
    val category: String,
    val totalMinutes: Long
)

@Dao
interface AppUsageDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertOrUpdate(usage: AppUsageEntity): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(usages: List<AppUsageEntity>)

    @Query("SELECT * FROM app_usage WHERE date = :date ORDER BY durationMinutes DESC")
    fun getUsageForDate(date: String): Flow<List<AppUsageEntity>>

    @Query("SELECT * FROM app_usage WHERE date BETWEEN :startDate AND :endDate ORDER BY date DESC, durationMinutes DESC")
    fun getUsageBetweenDates(startDate: String, endDate: String): Flow<List<AppUsageEntity>>

    @Query("SELECT SUM(durationMinutes) FROM app_usage WHERE date = :date")
    fun getTotalDurationForDate(date: String): Flow<Long?>

    @Query("SELECT SUM(durationMinutes) FROM app_usage WHERE date = :date AND category = :category")
    fun getCategoryDurationForDate(date: String, category: String): Flow<Long?>

    @Query("SELECT category, SUM(durationMinutes) as totalMinutes FROM app_usage WHERE date = :date GROUP BY category ORDER BY totalMinutes DESC")
    fun getCategorySummariesForDate(date: String): Flow<List<CategoryUsageSummary>>

    @Query("SELECT * FROM app_usage WHERE date = :date ORDER BY durationMinutes DESC LIMIT :limit")
    fun getTopAppsForDate(date: String, limit: Int = 5): Flow<List<AppUsageEntity>>

    @Query("SELECT * FROM app_usage WHERE packageName = :packageName AND date = :date LIMIT 1")
    suspend fun getUsageForPackageOnDate(packageName: String, date: String): AppUsageEntity?

    @Query("DELETE FROM app_usage WHERE date = :date")
    suspend fun deleteUsageForDate(date: String)

    @Query("DELETE FROM app_usage")
    suspend fun deleteAllUsage()
}
