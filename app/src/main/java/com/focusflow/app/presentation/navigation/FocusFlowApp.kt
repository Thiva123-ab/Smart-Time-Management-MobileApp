package com.focusflow.app.presentation.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.focusflow.app.presentation.analytics.AnalyticsScreen
import com.focusflow.app.presentation.analytics.AnalyticsViewModel
import com.focusflow.app.presentation.dashboard.DashboardScreen
import com.focusflow.app.presentation.dashboard.DashboardViewModel
import com.focusflow.app.presentation.focus.FocusScreen
import com.focusflow.app.presentation.focus.FocusViewModel
import com.focusflow.app.presentation.goals.GoalsScreen
import com.focusflow.app.presentation.goals.GoalsViewModel
import com.focusflow.app.presentation.settings.SettingsScreen
import com.focusflow.app.presentation.settings.SettingsViewModel
import com.focusflow.app.presentation.theme.*
import com.focusflow.app.presentation.usage.UsageScreen
import com.focusflow.app.presentation.usage.UsageViewModel

@Composable
fun FocusFlowApp() {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    Scaffold(
        bottomBar = {
            NavigationBar(
                containerColor = DarkSurface,
                tonalElevation = 8.dp
            ) {
                Screen.bottomNavItems.forEach { screen ->
                    val isSelected = currentRoute == screen.route
                    NavigationBarItem(
                        selected = isSelected,
                        onClick = {
                            navController.navigate(screen.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = {
                            Icon(
                                imageVector = screen.icon,
                                contentDescription = screen.title
                            )
                        },
                        label = { Text(screen.title) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = AccentCyan,
                            selectedTextColor = AccentCyan,
                            unselectedIconColor = TextMutedDark,
                            unselectedTextColor = TextMutedDark,
                            indicatorColor = DarkSurfaceVariant
                        )
                    )
                }
            }
        },
        containerColor = DarkBackground
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Screen.Dashboard.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            composable(Screen.Dashboard.route) {
                val vm: DashboardViewModel = viewModel()
                DashboardScreen(
                    viewModel = vm,
                    onNavigateToFocus = { navController.navigate(Screen.Focus.route) },
                    onNavigateToGoals = { navController.navigate(Screen.Goals.route) }
                )
            }
            composable(Screen.Usage.route) {
                val vm: UsageViewModel = viewModel()
                UsageScreen(viewModel = vm)
            }
            composable(Screen.Goals.route) {
                val vm: GoalsViewModel = viewModel()
                GoalsScreen(viewModel = vm)
            }
            composable(Screen.Focus.route) {
                val vm: FocusViewModel = viewModel()
                FocusScreen(viewModel = vm)
            }
            composable(Screen.Analytics.route) {
                val vm: AnalyticsViewModel = viewModel()
                AnalyticsScreen(viewModel = vm)
            }
            composable(Screen.Settings.route) {
                val vm: SettingsViewModel = viewModel()
                SettingsScreen(
                    viewModel = vm,
                    onNavigateToAI = { navController.navigate("ai_assistant") },
                    onNavigateToAchievements = { navController.navigate("achievements") }
                )
            }
            composable("ai_assistant") {
                val vm: com.focusflow.app.presentation.ai.AIViewModel = viewModel()
                com.focusflow.app.presentation.ai.AIAssistantScreen(
                    viewModel = vm,
                    onNavigateBack = { navController.popBackStack() }
                )
            }
            composable("achievements") {
                val vm: com.focusflow.app.presentation.achievements.AchievementsViewModel = viewModel()
                com.focusflow.app.presentation.achievements.AchievementsScreen(
                    viewModel = vm,
                    onNavigateBack = { navController.popBackStack() }
                )
            }
        }
    }
}
