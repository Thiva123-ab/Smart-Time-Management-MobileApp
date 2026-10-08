package com.focusflow.app.presentation.settings

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DeleteForever
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.focusflow.app.presentation.theme.*
import com.focusflow.app.utils.PermissionHelper

@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel,
    onNavigateToAI: () -> Unit = {},
    onNavigateToAchievements: () -> Unit = {}
) {
    val state by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    var showDeleteConfirmDialog by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        viewModel.checkPermissions()
    }

    state.exportStatusMessage?.let { msg ->
        LaunchedEffect(msg) {
            Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
            viewModel.clearStatusMessage()
        }
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBackground)
            .padding(horizontal = 20.dp),
        contentPadding = PaddingValues(top = 24.dp, bottom = 100.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp)
    ) {
        item {
            Column {
                Text(
                    text = "Settings & Privacy",
                    style = MaterialTheme.typography.headlineLarge,
                    color = TextPrimaryDark
                )
                Text(
                    text = "Local-first data management and app configuration",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondaryDark
                )
            }
        }

        // Quick Navigation to AI & Badges
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Card(
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = PrimaryPurple.copy(alpha = 0.2f)),
                    onClick = onNavigateToAI
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("🤖 AI Assistant", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = AccentCyan)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text("Smart schedules & habit advice", style = MaterialTheme.typography.bodySmall, color = TextSecondaryDark)
                    }
                }

                Card(
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = AccentCyan.copy(alpha = 0.15f)),
                    onClick = onNavigateToAchievements
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("🏆 Badges & Streaks", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = SuccessGreen)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text("Gamified milestones", style = MaterialTheme.typography.bodySmall, color = TextSecondaryDark)
                    }
                }
            }
        }

        // System Permissions Card
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = DarkSurface)
            ) {
                Column(modifier = Modifier.padding(18.dp)) {
                    Text("Android Permissions", style = MaterialTheme.typography.titleMedium, color = TextPrimaryDark)
                    Spacer(modifier = Modifier.height(14.dp))

                    // Usage Stats Permission
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text("Usage Access", style = MaterialTheme.typography.bodyLarge, color = TextPrimaryDark)
                            Text("Required for automatic tracking", style = MaterialTheme.typography.bodySmall, color = TextSecondaryDark)
                        }
                        if (state.hasUsagePermission) {
                            Icon(Icons.Default.CheckCircle, contentDescription = null, tint = SuccessGreen)
                        } else {
                            Button(
                                onClick = { context.startActivity(PermissionHelper.getUsageAccessSettingsIntent()) },
                                colors = ButtonDefaults.buttonColors(containerColor = WarningOrange),
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Text("Grant", color = DarkBackground)
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))
                    HorizontalDivider(color = DarkCardBorder)
                    Spacer(modifier = Modifier.height(14.dp))

                    // Notifications Permission
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text("Notifications", style = MaterialTheme.typography.bodyLarge, color = TextPrimaryDark)
                            Text("Budget alerts and session reminders", style = MaterialTheme.typography.bodySmall, color = TextSecondaryDark)
                        }
                        if (state.hasNotificationPermission) {
                            Icon(Icons.Default.CheckCircle, contentDescription = null, tint = SuccessGreen)
                        } else {
                            Text("Disabled", style = MaterialTheme.typography.bodySmall, color = WarningOrange)
                        }
                    }
                }
            }
        }

        // Data & Privacy Card
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = DarkSurface)
            ) {
                Column(modifier = Modifier.padding(18.dp)) {
                    Text("Privacy & Local Data", style = MaterialTheme.typography.titleMedium, color = TextPrimaryDark)
                    Spacer(modifier = Modifier.height(14.dp))

                    // Export Data Button
                    OutlinedButton(
                        onClick = {
                            Toast.makeText(context, "Exporting usage history to CSV/JSON...", Toast.LENGTH_SHORT).show()
                        },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = AccentCyan)
                    ) {
                        Icon(Icons.Default.Download, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Export My Data (JSON / CSV)")
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // Delete Today's Data
                    OutlinedButton(
                        onClick = { viewModel.deleteTodayData() },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = WarningOrange)
                    ) {
                        Text("Clear Today's Usage")
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // Delete All Data Button
                    Button(
                        onClick = { showDeleteConfirmDialog = true },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = DangerRed)
                    ) {
                        Icon(Icons.Default.DeleteForever, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Erase All Local Data")
                    }
                }
            }
        }

        // About Card
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = DarkSurface)
            ) {
                Column(modifier = Modifier.padding(18.dp)) {
                    Text("FocusFlow v1.0.0", style = MaterialTheme.typography.titleMedium, color = TextPrimaryDark)
                    Text("Local-First Digital Wellbeing & Time Management", style = MaterialTheme.typography.bodySmall, color = TextSecondaryDark)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("All personal tracking data is stored on-device in an encrypted Room SQLite database.", style = MaterialTheme.typography.bodySmall, color = TextMutedDark)
                }
            }
        }
    }

    if (showDeleteConfirmDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirmDialog = false },
            title = { Text("Erase All Data?", color = TextPrimaryDark) },
            text = { Text("This will permanently delete all your tracking history, goals, and focus sessions stored locally.", color = TextSecondaryDark) },
            confirmButton = {
                Button(
                    onClick = {
                        viewModel.deleteAllData()
                        showDeleteConfirmDialog = false
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = DangerRed)
                ) {
                    Text("Erase Everything")
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirmDialog = false }) {
                    Text("Cancel", color = TextSecondaryDark)
                }
            },
            containerColor = DarkSurface
        )
    }
}
