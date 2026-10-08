package com.focusflow.app.domain

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class FocusSessionState(
    val isActive: Boolean = false,
    val isPaused: Boolean = false,
    val taskName: String = "",
    val plannedMinutes: Long = 25,
    val elapsedSeconds: Long = 0,
    val distractionCount: Int = 0,
    val startTime: Long = 0
)

data class FocusSessionSummary(
    val taskName: String,
    val plannedMinutes: Long,
    val completedMinutes: Long,
    val distractionCount: Int,
    val completed: Boolean
)

class FocusModeManager {

    private val _state = MutableStateFlow(FocusSessionState())
    val state: StateFlow<FocusSessionState> = _state.asStateFlow()

    fun startSession(taskName: String, plannedMinutes: Long) {
        _state.value = FocusSessionState(
            isActive = true,
            isPaused = false,
            taskName = taskName,
            plannedMinutes = plannedMinutes,
            elapsedSeconds = 0,
            distractionCount = 0,
            startTime = System.currentTimeMillis()
        )
    }

    fun pauseSession() {
        if (_state.value.isActive) {
            _state.value = _state.value.copy(isPaused = true)
        }
    }

    fun resumeSession() {
        if (_state.value.isActive) {
            _state.value = _state.value.copy(isPaused = false)
        }
    }

    fun tick(): Boolean {
        val current = _state.value
        if (!current.isActive || current.isPaused) return false

        val newElapsed = current.elapsedSeconds + 1
        _state.value = current.copy(elapsedSeconds = newElapsed)

        // Check if session has reached target
        return newElapsed >= (current.plannedMinutes * 60)
    }

    fun recordDistraction() {
        val current = _state.value
        if (current.isActive) {
            _state.value = current.copy(distractionCount = current.distractionCount + 1)
        }
    }

    fun finishSession(isSuccess: Boolean): FocusSessionSummary {
        val current = _state.value
        val completedMinutes = (current.elapsedSeconds / 60).coerceAtLeast(1)

        val summary = FocusSessionSummary(
            taskName = current.taskName,
            plannedMinutes = current.plannedMinutes,
            completedMinutes = completedMinutes,
            distractionCount = current.distractionCount,
            completed = isSuccess || (current.elapsedSeconds >= current.plannedMinutes * 60)
        )

        _state.value = FocusSessionState() // Reset
        return summary
    }
}
