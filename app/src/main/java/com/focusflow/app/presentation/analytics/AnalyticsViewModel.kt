package com.focusflow.app.presentation.analytics

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.focusflow.app.data.local.dao.CategoryUsageSummary
import com.focusflow.app.data.local.database.FocusFlowDatabase
import com.focusflow.app.data.local.entities.DailyScoreEntity
import com.focusflow.app.data.repository.AnalyticsRepository
import com.focusflow.app.data.repository.AppUsageRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class AnalyticsUiState(
    val categorySummaries: List<CategoryUsageSummary> = emptyList(),
    val recentScores: List<DailyScoreEntity> = emptyList(),
    val totalScreenTimeMinutes: Long = 0,
    val averageScore: Int = 82,
    val bestDay: String = "Wednesday",
    val isLoading: Boolean = false
)

class AnalyticsViewModel(application: Application) : AndroidViewModel(application) {

    private val db = FocusFlowDatabase.getInstance(application)
    private val appUsageRepo = AppUsageRepository(db.appUsageDao())
    private val analyticsRepo = AnalyticsRepository(db.dailyScoreDao())

    private val _uiState = MutableStateFlow(AnalyticsUiState())
    val uiState: StateFlow<AnalyticsUiState> = _uiState.asStateFlow()

    init {
        loadAnalytics()
    }

    fun loadAnalytics() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)

            appUsageRepo.getCategorySummariesForDate().collect { summaries ->
                val total = summaries.sumOf { it.totalMinutes }
                _uiState.value = _uiState.value.copy(
                    categorySummaries = summaries,
                    totalScreenTimeMinutes = total,
                    isLoading = false
                )
            }
        }

        viewModelScope.launch {
            analyticsRepo.getRecentScores(7).collect { scores ->
                val avg = if (scores.isNotEmpty()) (scores.sumOf { it.score } / scores.size) else 82
                _uiState.value = _uiState.value.copy(
                    recentScores = scores,
                    averageScore = avg
                )
            }
        }
    }
}
