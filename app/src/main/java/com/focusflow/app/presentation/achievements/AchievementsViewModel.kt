package com.focusflow.app.presentation.achievements

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.focusflow.app.data.local.database.FocusFlowDatabase
import com.focusflow.app.data.local.entities.AchievementEntity
import com.focusflow.app.domain.AchievementEngine
import com.focusflow.app.domain.StreakManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class AchievementsUiState(
    val streakDays: Int = 3,
    val achievements: List<AchievementEntity> = emptyList(),
    val unlockedCount: Int = 0
)

class AchievementsViewModel(application: Application) : AndroidViewModel(application) {

    private val db = FocusFlowDatabase.getInstance(application)
    private val achievementDao = db.achievementDao()
    private val scoreDao = db.dailyScoreDao()
    private val focusDao = db.focusSessionDao()

    private val _uiState = MutableStateFlow(AchievementsUiState())
    val uiState: StateFlow<AchievementsUiState> = _uiState.asStateFlow()

    init {
        loadAchievements()
    }

    fun loadAchievements() {
        viewModelScope.launch {
            val scores = scoreDao.getRecentScores(30)
            scores.collect { scoreList ->
                val streak = StreakManager.calculateStreak(scoreList)

                achievementDao.getAllAchievements().collect { list ->
                    val totalFocus = focusDao.getAllTimeFocusMinutes() ?: 0L
                    val sessionCount = focusDao.getCompletedSessionCountForDate(
                        java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault()).format(java.util.Date())
                    )

                    val updated = AchievementEngine.evaluateAchievements(
                        currentAchievements = list,
                        completedFocusSessionsCount = sessionCount,
                        totalFocusMinutes = totalFocus,
                        streakDays = streak,
                        completedGoalsCount = 5,
                        socialMediaOverBudget = false
                    )

                    // Persist any newly unlocked achievements
                    updated.filter { it.isUnlocked }.forEach { achievementDao.update(it) }

                    _uiState.value = AchievementsUiState(
                        streakDays = streak,
                        achievements = updated,
                        unlockedCount = updated.count { it.isUnlocked }
                    )
                }
            }
        }
    }
}
