package com.focusflow.app.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.focusflow.app.data.local.entities.FocusSessionEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface FocusSessionDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSession(session: FocusSessionEntity): Long

    @Query("SELECT * FROM focus_sessions WHERE date = :date ORDER BY startTime DESC")
    fun getSessionsForDate(date: String): Flow<List<FocusSessionEntity>>

    @Query("SELECT * FROM focus_sessions ORDER BY startTime DESC")
    fun getAllSessions(): Flow<List<FocusSessionEntity>>

    @Query("SELECT SUM(durationMinutes) FROM focus_sessions WHERE date = :date AND completed = 1")
    fun getTotalFocusMinutesForDate(date: String): Flow<Long?>

    @Query("SELECT COUNT(*) FROM focus_sessions WHERE date = :date AND completed = 1")
    suspend fun getCompletedSessionCountForDate(date: String): Int

    @Query("SELECT SUM(durationMinutes) FROM focus_sessions WHERE completed = 1")
    suspend fun getAllTimeFocusMinutes(): Long?

    @Query("DELETE FROM focus_sessions WHERE sessionId = :sessionId")
    suspend fun deleteSession(sessionId: Long)
}
