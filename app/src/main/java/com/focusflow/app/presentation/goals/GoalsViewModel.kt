package com.focusflow.app.presentation.goals

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.focusflow.app.data.local.database.FocusFlowDatabase
import com.focusflow.app.data.local.entities.GoalEntity
import com.focusflow.app.data.local.entities.TimeBudgetEntity
import com.focusflow.app.data.repository.AppUsageRepository
import com.focusflow.app.data.repository.BudgetRepository
import com.focusflow.app.data.repository.GoalRepository
import com.focusflow.app.domain.usecase.BudgetStatus
import com.focusflow.app.domain.usecase.EvaluateBudgetsUseCase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class GoalsUiState(
    val goals: List<GoalEntity> = emptyList(),
    val budgetStatuses: List<BudgetStatus> = emptyList(),
    val isLoading: Boolean = false
)

class GoalsViewModel(application: Application) : AndroidViewModel(application) {

    private val db = FocusFlowDatabase.getInstance(application)
    private val goalRepo = GoalRepository(db.goalDao())
    private val budgetRepo = BudgetRepository(db.timeBudgetDao(), db.appLimitDao())
    private val appUsageRepo = AppUsageRepository(db.appUsageDao())
    private val evaluateBudgetsUseCase = EvaluateBudgetsUseCase(budgetRepo, appUsageRepo)

    private val _uiState = MutableStateFlow(GoalsUiState())
    val uiState: StateFlow<GoalsUiState> = _uiState.asStateFlow()

    init {
        loadData()
    }

    fun loadData() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            val budgetStatuses = evaluateBudgetsUseCase.getCategoryBudgetStatuses()
            goalRepo.getGoalsForDate().collect { goalsList ->
                _uiState.value = _uiState.value.copy(
                    goals = goalsList,
                    budgetStatuses = budgetStatuses,
                    isLoading = false
                )
            }
        }
    }

    fun addGoal(title: String, category: String, targetMinutes: Long) {
        viewModelScope.launch {
            goalRepo.createGoal(title, category, targetMinutes)
            loadData()
        }
    }

    fun toggleGoal(goal: GoalEntity) {
        viewModelScope.launch {
            goalRepo.toggleGoalCompleted(goal)
            loadData()
        }
    }

    fun deleteGoal(goalId: Long) {
        viewModelScope.launch {
            goalRepo.deleteGoal(goalId)
            loadData()
        }
    }

    fun updateBudget(category: String, limitMinutes: Long) {
        viewModelScope.launch {
            budgetRepo.setCategoryBudget(category, limitMinutes)
            loadData()
        }
    }
}
