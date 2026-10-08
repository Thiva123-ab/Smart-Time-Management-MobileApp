package com.focusflow.app.data.repository

import com.focusflow.app.data.local.dao.FocusSessionDao
import com.focusflow.app.data.local.dao.PomodoroDao
import com.focusflow.app.data.local.entities.FocusSessionEntity
import com.focusflow.app.data.local.entities.PomodoroEntity
import kotlinx.coroutines.flow.Flow
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class FocusRepository(
    private val focusSessionDao: FocusSessionDao,
    private val pomodoroDao: PomodoroDao
) {
    private fun getTodayDate(): String {
        return SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
    }

    fun getSessionsForDate(date: String = getTodayDate()): Flow<List<FocusSessionEntity>> =
        focusSessionDao.getSessionsForDate(date)

    fun getAllSessions(): Flow<List<FocusSessionEntity>> =
        focusSessionDao.getAllSessions()

    fun getTotalFocusMinutesForDate(date: String = getTodayDate()): Flow<Long?> =
        focusSessionDao.getTotalFocusMinutesForDate(date)

    suspend fun saveFocusSession(
        taskName: String,
        startTime: Long,
        endTime: Long,
        durationMinutes: Long,
        completed: Boolean,
        distractionCount: Int = 0,
        date: String = getTodayDate()
    ): Long {
        val session = FocusSessionEntity(
            taskName = taskName,
            startTime = startTime,
            endTime = endTime,
            durationMinutes = durationMinutes,
            completed = completed,
            distractionCount = distractionCount,
            date = date
        )
        return focusSessionDao.insertSession(session)
    }

    suspend fun savePomodoro(
        focusMinutes: Int,
        breakMinutes: Int,
        startTime: Long,
        endTime: Long,
        completed: Boolean,
        date: String = getTodayDate()
    ): Long {
        val session = PomodoroEntity(
            focusMinutes = focusMinutes,
            breakMinutes = breakMinutes,
            startTime = startTime,
            endTime = endTime,
            completed = completed,
            date = date
        )
        return pomodoroDao.insertPomodoro(session)
    }

    fun getPomodorosForDate(date: String = getTodayDate()): Flow<List<PomodoroEntity>> =
        pomodoroDao.getPomodoroSessionsForDate(date)

    fun getCompletedPomodoroCountForDate(date: String = getTodayDate()): Flow<Int> =
        pomodoroDao.getCompletedPomodoroCountForDate(date)
}
