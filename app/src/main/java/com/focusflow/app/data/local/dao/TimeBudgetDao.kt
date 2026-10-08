package com.focusflow.app.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.focusflow.app.data.local.entities.TimeBudgetEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface TimeBudgetDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertOrUpdate(budget: TimeBudgetEntity): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(budgets: List<TimeBudgetEntity>)

    @Query("SELECT * FROM time_budgets ORDER BY category ASC")
    fun getAllBudgets(): Flow<List<TimeBudgetEntity>>

    @Query("SELECT * FROM time_budgets WHERE category = :category LIMIT 1")
    fun getBudgetForCategory(category: String): Flow<TimeBudgetEntity?>

    @Query("SELECT * FROM time_budgets WHERE enabled = 1")
    suspend fun getActiveBudgets(): List<TimeBudgetEntity>

    @Query("DELETE FROM time_budgets WHERE budgetId = :budgetId")
    suspend fun deleteBudget(budgetId: Long)
}
