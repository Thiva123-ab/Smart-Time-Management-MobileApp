package com.focusflow.app.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.focusflow.app.data.local.entities.PomodoroEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface PomodoroDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPomodoro(pomodoro: PomodoroEntity): Long

    @Query("SELECT * FROM pomodoro_sessions WHERE date = :date ORDER BY startTime DESC")
    fun getPomodoroSessionsForDate(date: String): Flow<List<PomodoroEntity>>

    @Query("SELECT COUNT(*) FROM pomodoro_sessions WHERE date = :date AND completed = 1")
    fun getCompletedPomodoroCountForDate(date: String): Flow<Int>

    @Query("SELECT COUNT(*) FROM pomodoro_sessions WHERE completed = 1")
    suspend fun getAllTimeCompletedPomodoroCount(): Int
}
