package com.focusflow.app.data.local.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "users")
data class UserEntity(
    @PrimaryKey val userId: String = "default_user",
    val name: String = "User",
    val email: String = "",
    val profileImage: String? = null,
    val createdAt: Long = System.currentTimeMillis()
)
