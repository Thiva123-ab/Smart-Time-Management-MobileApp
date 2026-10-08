package com.focusflow.app.presentation.usage

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.HourglassBottom
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.focusflow.app.data.local.entities.AppUsageEntity
import com.focusflow.app.domain.AppCategoryManager
import com.focusflow.app.presentation.theme.*

@Composable
fun UsageScreen(viewModel: UsageViewModel) {
    val state by viewModel.uiState.collectAsState()
    var selectedAppForLimit by remember { mutableStateOf<AppUsageEntity?>(null) }

    val categories = listOf("All") + AppCategoryManager.ALL_CATEGORIES

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBackground)
            .padding(horizontal = 20.dp),
        contentPadding = PaddingValues(top = 24.dp, bottom = 100.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Column {
                Text(
                    text = "App Usage",
                    style = MaterialTheme.typography.headlineLarge,
                    color = TextPrimaryDark
                )
                Text(
                    text = "Detailed tracking across your installed applications",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondaryDark
                )
            }
        }

        // Category Filter Chips
        item {
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(vertical = 4.dp)
            ) {
                items(categories) { category ->
                    val isSelected = category == state.selectedCategory
                    FilterChip(
                        selected = isSelected,
                        onClick = { viewModel.selectCategory(category) },
                        label = { Text(category) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = PrimaryPurple,
                            selectedLabelColor = TextPrimaryDark,
                            containerColor = DarkSurface,
                            labelColor = TextSecondaryDark
                        ),
                        shape = RoundedCornerShape(20.dp)
                    )
                }
            }
        }

        items(state.filteredApps) { app ->
            val limit = state.limits.find { it.packageName == app.packageName }
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { selectedAppForLimit = app },
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = DarkSurface)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(42.dp)
                                .clip(RoundedCornerShape(10.dp))
                                .background(DarkSurfaceVariant),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = app.appName.take(1),
                                style = MaterialTheme.typography.titleMedium,
                                color = AccentCyan,
                                fontWeight = FontWeight.Bold
                            )
                        }
                        Spacer(modifier = Modifier.width(14.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = app.appName,
                                style = MaterialTheme.typography.titleMedium,
                                color = TextPrimaryDark
                            )
                            Text(
                                text = "${app.category} • ${app.launchCount} opens",
                                style = MaterialTheme.typography.bodySmall,
                                color = TextMutedDark
                            )
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Text(
                                text = formatMinutes(app.durationMinutes),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = TextPrimaryDark
                            )
                            if (limit != null) {
                                Text(
                                    text = "Limit: ${limit.limitMinutes}m",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = if (app.durationMinutes >= limit.limitMinutes) DangerRed else WarningOrange
                                )
                            }
                        }
                    }

                    // Progress bar compared to total or limit
                    Spacer(modifier = Modifier.height(10.dp))
                    val progress = if (limit != null && limit.limitMinutes > 0) {
                        (app.durationMinutes.toFloat() / limit.limitMinutes.toFloat()).coerceIn(0f, 1f)
                    } else {
                        if (state.totalTimeMinutes > 0) (app.durationMinutes.toFloat() / state.totalTimeMinutes.toFloat()) else 0f
                    }

                    LinearProgressIndicator(
                        progress = { progress },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(6.dp)
                            .clip(RoundedCornerShape(3.dp)),
                        color = when {
                            limit != null && app.durationMinutes >= limit.limitMinutes -> DangerRed
                            AppCategoryManager.isProductive(app.category) -> SuccessGreen
                            AppCategoryManager.isDistracting(app.category) -> PrimaryPurple
                            else -> InfoBlue
                        },
                        trackColor = DarkCardBorder
                    )
                }
            }
        }
    }

    // Dialog to set app limit
    selectedAppForLimit?.let { app ->
        var limitInput by remember { mutableStateOf("60") }
        AlertDialog(
            onDismissRequest = { selectedAppForLimit = null },
            title = { Text("Set Daily Limit for ${app.appName}", color = TextPrimaryDark) },
            text = {
                Column {
                    Text("Daily time limit in minutes:", color = TextSecondaryDark)
                    Spacer(modifier = Modifier.height(12.dp))
                    OutlinedTextField(
                        value = limitInput,
                        onValueChange = { limitInput = it },
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = PrimaryPurple,
                            unfocusedBorderColor = DarkCardBorder,
                            focusedTextColor = TextPrimaryDark,
                            unfocusedTextColor = TextPrimaryDark
                        )
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val mins = limitInput.toLongOrNull() ?: 60
                        viewModel.setAppLimit(app.packageName, app.appName, mins)
                        selectedAppForLimit = null
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = PrimaryPurple)
                ) {
                    Text("Save Limit")
                }
            },
            dismissButton = {
                TextButton(onClick = { selectedAppForLimit = null }) {
                    Text("Cancel", color = TextSecondaryDark)
                }
            },
            containerColor = DarkSurface
        )
    }
}

private fun formatMinutes(minutes: Long): String {
    val hours = minutes / 60
    val mins = minutes % 60
    return if (hours > 0) "${hours}h ${mins}m" else "${mins}m"
}
