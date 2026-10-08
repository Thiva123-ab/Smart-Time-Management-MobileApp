package com.focusflow.app.data.repository

import com.focusflow.app.data.local.dao.GoalDao
import com.focusflow.app.data.local.entities.GoalEntity
import kotlinx.coroutines.flow.Flow
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class GoalRepository(private val goalDao: GoalDao) {

    private fun getTodayDate(): String {
        return SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
    }

    fun getGoalsForDate(date: String = getTodayDate()): Flow<List<GoalEntity>> {
        return goalDao.getGoalsForDate(date)
    }

    fun getGoalById(goalId: Long): Flow<GoalEntity?> {
        return goalDao.getGoalById(goalId)
    }

    suspend fun createGoal(title: String, category: String, targetMinutes: Long, date: String = getTodayDate()): Long {
        val goal = GoalEntity(
            title = title,
            category = category,
            targetMinutes = targetMinutes,
            completedMinutes = 0,
            date = date,
            status = "IN_PROGRESS"
        )
        return goalDao.insertGoal(goal)
    }

    suspend fun updateGoalProgress(goal: GoalEntity, addedMinutes: Long) {
        val newCompleted = goal.completedMinutes + addedMinutes
        val status = if (newCompleted >= goal.targetMinutes) "COMPLETED" else "IN_PROGRESS"
        goalDao.updateGoal(goal.copy(completedMinutes = newCompleted, status = status))
    }

    suspend fun toggleGoalCompleted(goal: GoalEntity) {
        val newStatus = if (goal.status == "COMPLETED") "IN_PROGRESS" else "COMPLETED"
        val completedMinutes = if (newStatus == "COMPLETED") goal.targetMinutes else 0
        goalDao.updateGoal(goal.copy(status = newStatus, completedMinutes = completedMinutes))
    }

    suspend fun deleteGoal(goalId: Long) {
        goalDao.deleteGoal(goalId)
    }

    suspend fun getGoalCompletionPercentage(date: String = getTodayDate()): Int {
        val total = goalDao.getTotalGoalsCountForDate(date)
        if (total == 0) return 100 // No goals means no failed goals
        val completed = goalDao.getCompletedGoalsCountForDate(date)
        return (completed * 100) / total
    }
}
