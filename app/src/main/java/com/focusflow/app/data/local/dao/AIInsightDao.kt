package com.focusflow.app.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.focusflow.app.data.local.entities.AIInsightEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface AIInsightDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertInsight(insight: AIInsightEntity): Long

    @Query("SELECT * FROM ai_insights ORDER BY createdAt DESC LIMIT :limit")
    fun getRecentInsights(limit: Int = 10): Flow<List<AIInsightEntity>>

    @Query("SELECT * FROM ai_insights WHERE date = :date ORDER BY createdAt DESC")
    fun getInsightsForDate(date: String): Flow<List<AIInsightEntity>>

    @Query("DELETE FROM ai_insights")
    suspend fun clearAll()
}
