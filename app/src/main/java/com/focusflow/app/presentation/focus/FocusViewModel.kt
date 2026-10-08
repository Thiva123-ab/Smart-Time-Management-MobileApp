package com.focusflow.app.presentation.focus

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.focusflow.app.data.local.database.FocusFlowDatabase
import com.focusflow.app.data.repository.FocusRepository
import com.focusflow.app.domain.*
import com.focusflow.app.utils.NotificationHelper
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class FocusViewModel(application: Application) : AndroidViewModel(application) {

    private val db = FocusFlowDatabase.getInstance(application)
    private val focusRepo = FocusRepository(db.focusSessionDao(), db.pomodoroDao())

    val focusManager = FocusModeManager()
    val pomodoroEngine = PomodoroEngine()

    val focusState: StateFlow<FocusSessionState> = focusManager.state
    val pomodoroState: StateFlow<PomodoroState> = pomodoroEngine.state

    private val _lastSummary = MutableStateFlow<FocusSessionSummary?>(null)
    val lastSummary: StateFlow<FocusSessionSummary?> = _lastSummary.asStateFlow()

    private var focusTimerJob: Job? = null
    private var pomodoroTimerJob: Job? = null

    fun startFocusSession(taskName: String, durationMinutes: Long) {
        focusManager.startSession(taskName, durationMinutes)
        focusTimerJob?.cancel()
        focusTimerJob = viewModelScope.launch {
            while (focusManager.state.value.isActive) {
                delay(1000)
                val isFinished = focusManager.tick()
                if (isFinished) {
                    finishFocusSession(true)
                    break
                }
            }
        }
    }

    fun pauseFocus() = focusManager.pauseSession()
    fun resumeFocus() = focusManager.resumeSession()
    fun recordDistraction() = focusManager.recordDistraction()

    fun finishFocusSession(completed: Boolean) {
        focusTimerJob?.cancel()
        val summary = focusManager.finishSession(completed)
        _lastSummary.value = summary

        viewModelScope.launch {
            focusRepo.saveFocusSession(
                taskName = summary.taskName,
                startTime = System.currentTimeMillis() - (summary.completedMinutes * 60 * 1000),
                endTime = System.currentTimeMillis(),
                durationMinutes = summary.completedMinutes,
                completed = summary.completed,
                distractionCount = summary.distractionCount
            )
            NotificationHelper.showFocusComplete(
                getApplication(),
                summary.taskName,
                summary.completedMinutes,
                summary.distractionCount
            )
        }
    }

    fun dismissSummary() {
        _lastSummary.value = null
    }

    // Pomodoro Actions
    fun startPomodoro() {
        pomodoroEngine.startTimer()
        pomodoroTimerJob?.cancel()
        pomodoroTimerJob = viewModelScope.launch {
            while (pomodoroEngine.state.value.isRunning) {
                delay(1000)
                val phaseChanged = pomodoroEngine.tick()
                if (phaseChanged && pomodoroEngine.state.value.currentPhase != PomodoroPhase.FOCUS) {
                    // Record completed focus session in database
                    focusRepo.savePomodoro(
                        focusMinutes = pomodoroEngine.state.value.focusDurationMinutes,
                        breakMinutes = pomodoroEngine.state.value.breakDurationMinutes,
                        startTime = System.currentTimeMillis() - (pomodoroEngine.state.value.focusDurationMinutes * 60 * 1000),
                        endTime = System.currentTimeMillis(),
                        completed = true
                    )
                }
            }
        }
    }

    fun pausePomodoro() {
        pomodoroTimerJob?.cancel()
        pomodoroEngine.pauseTimer()
    }

    fun resetPomodoro() {
        pomodoroTimerJob?.cancel()
        pomodoroEngine.resetTimer()
    }

    fun applyPreset(preset: PomodoroPreset) = pomodoroEngine.applyPreset(preset)
}
