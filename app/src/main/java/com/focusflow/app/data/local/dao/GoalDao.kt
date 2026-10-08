package com.focusflow.app.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.focusflow.app.data.local.entities.GoalEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface GoalDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertGoal(goal: GoalEntity): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(goals: List<GoalEntity>)

    @Update
    suspend fun updateGoal(goal: GoalEntity)

    @Query("SELECT * FROM goals WHERE date = :date ORDER BY status ASC, targetMinutes DESC")
    fun getGoalsForDate(date: String): Flow<List<GoalEntity>>

    @Query("SELECT * FROM goals WHERE goalId = :goalId LIMIT 1")
    fun getGoalById(goalId: Long): Flow<GoalEntity?>

    @Query("SELECT COUNT(*) FROM goals WHERE date = :date")
    suspend fun getTotalGoalsCountForDate(date: String): Int

    @Query("SELECT COUNT(*) FROM goals WHERE date = :date AND status = 'COMPLETED'")
    suspend fun getCompletedGoalsCountForDate(date: String): Int

    @Query("DELETE FROM goals WHERE goalId = :goalId")
    suspend fun deleteGoal(goalId: Long)

    @Query("DELETE FROM goals")
    suspend fun deleteAllGoals()
}
