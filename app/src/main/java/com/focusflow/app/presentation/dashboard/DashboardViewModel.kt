package com.focusflow.app.presentation.dashboard

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.focusflow.app.data.local.database.FocusFlowDatabase
import com.focusflow.app.data.local.entities.AppUsageEntity
import com.focusflow.app.data.local.entities.GoalEntity
import com.focusflow.app.data.repository.AnalyticsRepository
import com.focusflow.app.data.repository.AppUsageRepository
import com.focusflow.app.data.repository.FocusRepository
import com.focusflow.app.data.repository.GoalRepository
import com.focusflow.app.domain.AppCategoryManager
import com.focusflow.app.domain.ProductivityScoreEngine
import com.focusflow.app.domain.ScoreBreakdown
import com.focusflow.app.domain.usecase.CalculateDailyScoreUseCase
import com.focusflow.app.services.UsageTrackingManager
import com.focusflow.app.utils.PermissionHelper
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class DashboardUiState(
    val score: ScoreBreakdown = ProductivityScoreEngine.calculateScore(80, 250, 85, 90),
    val totalScreenTimeMinutes: Long = 335,
    val productiveMinutes: Long = 250,
    val distractingMinutes: Long = 85,
    val topApps: List<AppUsageEntity> = emptyList(),
    val todayGoals: List<GoalEntity> = emptyList(),
    val hasUsagePermission: Boolean = false,
    val isLoading: Boolean = false
)

class DashboardViewModel(application: Application) : AndroidViewModel(application) {

    private val db = FocusFlowDatabase.getInstance(application)
    private val appUsageRepo = AppUsageRepository(db.appUsageDao())
    private val goalRepo = GoalRepository(db.goalDao())
    private val focusRepo = FocusRepository(db.focusSessionDao(), db.pomodoroDao())
    private val analyticsRepo = AnalyticsRepository(db.dailyScoreDao())
    private val calculateScoreUseCase = CalculateDailyScoreUseCase(appUsageRepo, goalRepo, focusRepo, analyticsRepo)
    private val usageTracker = UsageTrackingManager(application)

    private val _uiState = MutableStateFlow(DashboardUiState())
    val uiState: StateFlow<DashboardUiState> = _uiState.asStateFlow()

    init {
        loadDashboardData()
    }

    fun loadDashboardData() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            val hasPermission = PermissionHelper.hasUsageStatsPermission(getApplication())

            // Fetch and save latest usage data
            val usages = usageTracker.fetchTodayUsage()
            if (usages.isNotEmpty()) {
                appUsageRepo.saveAppUsageList(usages)
            }

            // Calculate productive vs distracting
            val productive = usages.filter { AppCategoryManager.isProductive(it.category) }.sumOf { it.durationMinutes }
            val distracting = usages.filter { AppCategoryManager.isDistracting(it.category) }.sumOf { it.durationMinutes }
            val total = usages.sumOf { it.durationMinutes }

            val scoreBreakdown = calculateScoreUseCase()

            // Observe goals
            goalRepo.getGoalsForDate().collect { goals ->
                _uiState.value = _uiState.value.copy(
                    score = scoreBreakdown,
                    totalScreenTimeMinutes = total,
                    productiveMinutes = productive,
                    distractingMinutes = distracting,
                    topApps = usages.take(5),
                    todayGoals = goals,
                    hasUsagePermission = hasPermission,
                    isLoading = false
                )
            }
        }
    }
}
