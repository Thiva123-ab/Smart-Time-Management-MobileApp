package com.focusflow.app.presentation.ai

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.focusflow.app.data.local.database.FocusFlowDatabase
import com.focusflow.app.data.local.entities.AIInsightEntity
import com.focusflow.app.data.remote.ai.AIPrivacyAggregator
import com.focusflow.app.data.remote.ai.GeminiAIService
import com.focusflow.app.data.repository.AppUsageRepository
import com.focusflow.app.data.repository.FocusRepository
import com.focusflow.app.data.repository.GoalRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.launch

data class ChatMessage(
    val sender: String, // "USER" or "AI"
    val message: String,
    val timestamp: Long = System.currentTimeMillis()
)

data class AIUiState(
    val messages: List<ChatMessage> = listOf(
        ChatMessage("AI", "Hello! I am your FocusFlow AI assistant 🤖. Ask me to analyze your screen time, create a tomorrow schedule, or get distraction tips.")
    ),
    val isThinking: Boolean = false
)

class AIViewModel(application: Application) : AndroidViewModel(application) {

    private val db = FocusFlowDatabase.getInstance(application)
    private val appUsageRepo = AppUsageRepository(db.appUsageDao())
    private val goalRepo = GoalRepository(db.goalDao())
    private val focusRepo = FocusRepository(db.focusSessionDao(), db.pomodoroDao())
    private val aiInsightDao = db.aiInsightDao()

    private val geminiService = GeminiAIService()

    private val _uiState = MutableStateFlow(AIUiState())
    val uiState: StateFlow<AIUiState> = _uiState.asStateFlow()

    fun askAI(query: String) {
        if (query.isBlank()) return

        val userMsg = ChatMessage("USER", query)
        _uiState.value = _uiState.value.copy(
            messages = _uiState.value.messages + userMsg,
            isThinking = true
        )

        viewModelScope.launch {
            val date = appUsageRepo.getTodayDate()
            val usages = appUsageRepo.getUsageForDate(date).firstOrNull() ?: emptyList()
            val focusSessions = focusRepo.getSessionsForDate(date).firstOrNull()?.size ?: 0
            val goalPercentage = goalRepo.getGoalCompletionPercentage(date)

            // Sanitize and aggregate privacy-preserving summary
            val summary = AIPrivacyAggregator.createSanitizedSummary(
                date = date,
                usages = usages,
                focusCount = focusSessions,
                goalCompletion = goalPercentage
            )

            val reply = geminiService.generateProductivityAdvice(summary, query)

            // Save insight in Room database
            aiInsightDao.insertInsight(
                AIInsightEntity(
                    date = date,
                    type = "ADVICE",
                    message = query,
                    recommendation = reply
                )
            )

            val aiMsg = ChatMessage("AI", reply)
            _uiState.value = _uiState.value.copy(
                messages = _uiState.value.messages + aiMsg,
                isThinking = false
            )
        }
    }
}
