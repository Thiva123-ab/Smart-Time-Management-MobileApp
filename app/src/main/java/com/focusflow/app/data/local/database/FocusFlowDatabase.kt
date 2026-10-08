package com.focusflow.app.data.local.database

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import com.focusflow.app.data.local.dao.*
import com.focusflow.app.data.local.entities.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

@Database(
    entities = [
        UserEntity::class,
        AppUsageEntity::class,
        TimeBudgetEntity::class,
        AppLimitEntity::class,
        GoalEntity::class,
        FocusSessionEntity::class,
        PomodoroEntity::class,
        AIInsightEntity::class,
        AchievementEntity::class,
        DailyScoreEntity::class
    ],
    version = 1,
    exportSchema = false
)
abstract class FocusFlowDatabase : RoomDatabase() {

    abstract fun userDao(): UserDao
    abstract fun appUsageDao(): AppUsageDao
    abstract fun timeBudgetDao(): TimeBudgetDao
    abstract fun appLimitDao(): AppLimitDao
    abstract fun goalDao(): GoalDao
    abstract fun focusSessionDao(): FocusSessionDao
    abstract fun pomodoroDao(): PomodoroDao
    abstract fun aiInsightDao(): AIInsightDao
    abstract fun achievementDao(): AchievementDao
    abstract fun dailyScoreDao(): DailyScoreDao

    companion object {
        @Volatile
        private var INSTANCE: FocusFlowDatabase? = null

        fun getInstance(context: Context): FocusFlowDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    FocusFlowDatabase::class.java,
                    "focusflow.db"
                )
                    .fallbackToDestructiveMigration()
                    .addCallback(DatabaseCallback(context.applicationContext))
                    .build()
                INSTANCE = instance
                instance
            }
        }

        private class DatabaseCallback(private val context: Context) : Callback() {
            override fun onCreate(db: SupportSQLiteDatabase) {
                super.onCreate(db)
                CoroutineScope(Dispatchers.IO).launch {
                    val database = getInstance(context)
                    // Seed initial achievements
                    val initialAchievements = listOf(
                        AchievementEntity("first_focus", "First Step", "Complete your first Focus Session", null, false, "FOCUS"),
                        AchievementEntity("focus_10_hours", "Deep Worker", "Complete 10 hours of focused work", null, false, "FOCUS"),
                        AchievementEntity("streak_3_days", "Momentum", "Maintain a 3-day productivity streak", null, false, "STREAK"),
                        AchievementEntity("streak_7_days", "Unstoppable", "Maintain a 7-day productivity streak", null, false, "STREAK"),
                        AchievementEntity("digital_balance", "Digital Balance", "Stay within all category budgets for a day", null, false, "DIGITAL_BALANCE"),
                        AchievementEntity("goals_master", "Goal Crusher", "Complete 20 daily goals", null, false, "GOALS")
                    )
                    database.achievementDao().insertAll(initialAchievements)

                    // Seed default category budgets
                    val defaultBudgets = listOf(
                        TimeBudgetEntity(category = "Social Media", limitMinutes = 60, date = "daily_default", enabled = true),
                        TimeBudgetEntity(category = "Gaming", limitMinutes = 45, date = "daily_default", enabled = true),
                        TimeBudgetEntity(category = "Entertainment", limitMinutes = 90, date = "daily_default", enabled = true)
                    )
                    database.timeBudgetDao().insertAll(defaultBudgets)
                }
            }
        }
    }
}
