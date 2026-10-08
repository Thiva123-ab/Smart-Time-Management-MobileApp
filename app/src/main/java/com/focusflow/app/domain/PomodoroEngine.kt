package com.focusflow.app.domain

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class PomodoroPhase {
    FOCUS,
    SHORT_BREAK,
    LONG_BREAK
}

data class PomodoroPreset(
    val title: String,
    val focusMinutes: Int,
    val breakMinutes: Int,
    val longBreakMinutes: Int = 15
)

data class PomodoroState(
    val isRunning: Boolean = false,
    val isPaused: Boolean = false,
    val currentPhase: PomodoroPhase = PomodoroPhase.FOCUS,
    val focusDurationMinutes: Int = 25,
    val breakDurationMinutes: Int = 5,
    val longBreakDurationMinutes: Int = 15,
    val remainingSeconds: Int = 25 * 60,
    val completedCycles: Int = 0,
    val totalFocusMinutesCompleted: Int = 0
)

class PomodoroEngine {

    companion object {
        val PRESET_25_5 = PomodoroPreset("Classic (25/5)", 25, 5, 15)
        val PRESET_50_10 = PomodoroPreset("Deep Work (50/10)", 50, 10, 20)
        val PRESET_90_15 = PomodoroPreset("Ultradian (90/15)", 90, 15, 30)
    }

    private val _state = MutableStateFlow(PomodoroState())
    val state: StateFlow<PomodoroState> = _state.asStateFlow()

    fun applyPreset(preset: PomodoroPreset) {
        _state.value = PomodoroState(
            focusDurationMinutes = preset.focusMinutes,
            breakDurationMinutes = preset.breakMinutes,
            longBreakDurationMinutes = preset.longBreakMinutes,
            remainingSeconds = preset.focusMinutes * 60,
            currentPhase = PomodoroPhase.FOCUS
        )
    }

    fun setCustomDuration(focusMin: Int, breakMin: Int) {
        _state.value = _state.value.copy(
            focusDurationMinutes = focusMin,
            breakDurationMinutes = breakMin,
            remainingSeconds = if (_state.value.currentPhase == PomodoroPhase.FOCUS) focusMin * 60 else breakMin * 60
        )
    }

    fun startTimer() {
        _state.value = _state.value.copy(isRunning = true, isPaused = false)
    }

    fun pauseTimer() {
        _state.value = _state.value.copy(isRunning = false, isPaused = true)
    }

    fun resetTimer() {
        val current = _state.value
        _state.value = PomodoroState(
            focusDurationMinutes = current.focusDurationMinutes,
            breakDurationMinutes = current.breakDurationMinutes,
            remainingSeconds = current.focusDurationMinutes * 60,
            currentPhase = PomodoroPhase.FOCUS,
            completedCycles = current.completedCycles,
            totalFocusMinutesCompleted = current.totalFocusMinutesCompleted
        )
    }

    /**
     * Called every second by the timer coroutine.
     * Returns true if a phase transition occurred (e.g. Focus completed -> Break started).
     */
    fun tick(): Boolean {
        val current = _state.value
        if (!current.isRunning || current.isPaused) return false

        if (current.remainingSeconds > 1) {
            _state.value = current.copy(remainingSeconds = current.remainingSeconds - 1)
            return false
        }

        // Phase finished! Transition to next phase
        when (current.currentPhase) {
            PomodoroPhase.FOCUS -> {
                val newCycles = current.completedCycles + 1
                val newTotalFocus = current.totalFocusMinutesCompleted + current.focusDurationMinutes
                val nextPhase = if (newCycles % 4 == 0) PomodoroPhase.LONG_BREAK else PomodoroPhase.SHORT_BREAK
                val nextDuration = if (nextPhase == PomodoroPhase.LONG_BREAK) current.longBreakDurationMinutes else current.breakDurationMinutes

                _state.value = current.copy(
                    currentPhase = nextPhase,
                    remainingSeconds = nextDuration * 60,
                    completedCycles = newCycles,
                    totalFocusMinutesCompleted = newTotalFocus,
                    isRunning = true
                )
                return true
            }
            PomodoroPhase.SHORT_BREAK, PomodoroPhase.LONG_BREAK -> {
                _state.value = current.copy(
                    currentPhase = PomodoroPhase.FOCUS,
                    remainingSeconds = current.focusDurationMinutes * 60,
                    isRunning = true
                )
                return true
            }
        }
    }
}
