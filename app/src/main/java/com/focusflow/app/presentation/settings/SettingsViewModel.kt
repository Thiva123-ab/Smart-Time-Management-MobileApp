package com.focusflow.app.presentation.settings

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.focusflow.app.data.local.database.FocusFlowDatabase
import com.focusflow.app.data.repository.AppUsageRepository
import com.focusflow.app.utils.PermissionHelper
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class SettingsUiState(
    val hasUsagePermission: Boolean = false,
    val hasNotificationPermission: Boolean = false,
    val bedtimeHour: Int = 22,
    val bedtimeMinute: Int = 30,
    val exportStatusMessage: String? = null
)

class SettingsViewModel(application: Application) : AndroidViewModel(application) {

    private val db = FocusFlowDatabase.getInstance(application)
    private val appUsageRepo = AppUsageRepository(db.appUsageDao())

    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    init {
        checkPermissions()
    }

    fun checkPermissions() {
        val app = getApplication<Application>()
        _uiState.value = _uiState.value.copy(
            hasUsagePermission = PermissionHelper.hasUsageStatsPermission(app),
            hasNotificationPermission = PermissionHelper.hasNotificationPermission(app)
        )
    }

    fun deleteTodayData() {
        viewModelScope.launch {
            appUsageRepo.clearTodayUsage()
            _uiState.value = _uiState.value.copy(exportStatusMessage = "Today's usage history deleted.")
        }
    }

    fun deleteAllData() {
        viewModelScope.launch {
            appUsageRepo.clearAllData()
            _uiState.value = _uiState.value.copy(exportStatusMessage = "All local tracking data erased.")
        }
    }

    fun clearStatusMessage() {
        _uiState.value = _uiState.value.copy(exportStatusMessage = null)
    }
}
