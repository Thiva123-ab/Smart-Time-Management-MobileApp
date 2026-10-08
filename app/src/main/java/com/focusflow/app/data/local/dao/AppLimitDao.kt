package com.focusflow.app.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.focusflow.app.data.local.entities.AppLimitEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface AppLimitDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertOrUpdate(limit: AppLimitEntity): Long

    @Query("SELECT * FROM app_limits ORDER BY appName ASC")
    fun getAllLimits(): Flow<List<AppLimitEntity>>

    @Query("SELECT * FROM app_limits WHERE packageName = :packageName LIMIT 1")
    fun getLimitForPackage(packageName: String): Flow<AppLimitEntity?>

    @Query("SELECT * FROM app_limits WHERE enabled = 1")
    suspend fun getActiveLimits(): List<AppLimitEntity>

    @Query("DELETE FROM app_limits WHERE limitId = :limitId")
    suspend fun deleteLimit(limitId: Long)
}
