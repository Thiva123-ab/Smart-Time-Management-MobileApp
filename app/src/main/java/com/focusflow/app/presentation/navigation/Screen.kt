package com.focusflow.app.presentation.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.HourglassTop
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.filled.Settings
import androidx.compose.ui.graphics.vector.ImageVector

sealed class Screen(val route: String, val title: String, val icon: ImageVector) {
    object Dashboard : Screen("dashboard", "Home", Icons.Default.Home)
    object Usage : Screen("usage", "Usage", Icons.Default.PhoneAndroid)
    object Goals : Screen("goals", "Goals", Icons.Default.CheckCircle)
    object Focus : Screen("focus", "Focus", Icons.Default.HourglassTop)
    object Analytics : Screen("analytics", "Stats", Icons.Default.BarChart)
    object Settings : Screen("settings", "Settings", Icons.Default.Settings)

    companion object {
        val bottomNavItems = listOf(
            Dashboard,
            Usage,
            Goals,
            Focus,
            Analytics,
            Settings
        )
    }
}
