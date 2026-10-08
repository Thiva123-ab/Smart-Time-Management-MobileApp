package com.focusflow.app.presentation.usage

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.focusflow.app.data.local.database.FocusFlowDatabase
import com.focusflow.app.data.local.entities.AppLimitEntity
import com.focusflow.app.data.local.entities.AppUsageEntity
import com.focusflow.app.data.repository.AppUsageRepository
import com.focusflow.app.data.repository.BudgetRepository
import com.focusflow.app.domain.AppCategoryManager
import com.focusflow.app.services.UsageTrackingManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class UsageUiState(
    val apps: List<AppUsageEntity> = emptyList(),
    val filteredApps: List<AppUsageEntity> = emptyList(),
    val selectedCategory: String = "All",
    val limits: List<AppLimitEntity> = emptyList(),
    val totalTimeMinutes: Long = 0,
    val isLoading: Boolean = false
)

class UsageViewModel(application: Application) : AndroidViewModel(application) {

    private val db = FocusFlowDatabase.getInstance(application)
    private val appUsageRepo = AppUsageRepository(db.appUsageDao())
    private val budgetRepo = BudgetRepository(db.timeBudgetDao(), db.appLimitDao())
    private val tracker = UsageTrackingManager(application)

    private val _uiState = MutableStateFlow(UsageUiState())
    val uiState: StateFlow<UsageUiState> = _uiState.asStateFlow()

    init {
        loadUsageData()
    }

    fun loadUsageData() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            val list = tracker.fetchTodayUsage()
            if (list.isNotEmpty()) {
                appUsageRepo.saveAppUsageList(list)
            }

            budgetRepo.getAllAppLimits().collect { limits ->
                val total = list.sumOf { it.durationMinutes }
                _uiState.value = _uiState.value.copy(
                    apps = list,
                    filteredApps = filterByCategory(list, _uiState.value.selectedCategory),
                    limits = limits,
                    totalTimeMinutes = total,
                    isLoading = false
                )
            }
        }
    }

    fun selectCategory(category: String) {
        _uiState.value = _uiState.value.copy(
            selectedCategory = category,
            filteredApps = filterByCategory(_uiState.value.apps, category)
        )
    }

    private fun filterByCategory(apps: List<AppUsageEntity>, category: String): List<AppUsageEntity> {
        return if (category == "All") apps else apps.filter { it.category == category }
    }

    fun setAppLimit(pkg: String, appName: String, limitMinutes: Long) {
        viewModelScope.launch {
            budgetRepo.setAppLimit(pkg, appName, limitMinutes)
            loadUsageData()
        }
    }

    fun updateAppCategory(app: AppUsageEntity, newCategory: String) {
        viewModelScope.launch {
            appUsageRepo.saveAppUsage(app.copy(category = newCategory))
            loadUsageData()
        }
    }
}
