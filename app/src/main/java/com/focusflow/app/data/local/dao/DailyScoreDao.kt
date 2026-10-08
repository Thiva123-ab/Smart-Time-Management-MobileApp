package com.focusflow.app.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.focusflow.app.data.local.entities.DailyScoreEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface DailyScoreDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertOrUpdate(score: DailyScoreEntity)

    @Query("SELECT * FROM daily_scores WHERE date = :date LIMIT 1")
    fun getScoreForDate(date: String): Flow<DailyScoreEntity?>

    @Query("SELECT * FROM daily_scores WHERE date = :date LIMIT 1")
    suspend fun getScoreForDateSync(date: String): DailyScoreEntity?

    @Query("SELECT * FROM daily_scores ORDER BY date DESC LIMIT :limit")
    fun getRecentScores(limit: Int = 30): Flow<List<DailyScoreEntity>>

    @Query("SELECT AVG(score) FROM daily_scores WHERE date BETWEEN :startDate AND :endDate")
    fun getAverageScoreBetweenDates(startDate: String, endDate: String): Flow<Double?>
}
