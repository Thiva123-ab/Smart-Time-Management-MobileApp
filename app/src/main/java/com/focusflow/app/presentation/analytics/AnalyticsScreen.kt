package com.focusflow.app.presentation.analytics

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.focusflow.app.domain.AppCategoryManager
import com.focusflow.app.presentation.theme.*

@Composable
fun AnalyticsScreen(viewModel: AnalyticsViewModel) {
    val state by viewModel.uiState.collectAsState()
    var selectedTimeframe by remember { mutableIntStateOf(0) } // 0: Daily, 1: Weekly, 2: Monthly

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
                    text = "Analytics & Trends",
                    style = MaterialTheme.typography.headlineLarge,
                    color = TextPrimaryDark
                )
                Text(
                    text = "Understand your digital habits and long-term progress",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondaryDark
                )
            }
        }

        // Timeframe selector
        item {
            TabRow(
                selectedTabIndex = selectedTimeframe,
                containerColor = DarkSurface,
                contentColor = PrimaryPurple,
                indicator = {},
                divider = {},
                modifier = Modifier.clip(RoundedCornerShape(12.dp))
            ) {
                listOf("Today", "This Week", "This Month").forEachIndexed { index, title ->
                    Tab(
                        selected = selectedTimeframe == index,
                        onClick = { selectedTimeframe = index },
                        text = {
                            Text(
                                text = title,
                                fontWeight = FontWeight.Bold,
                                color = if (selectedTimeframe == index) AccentCyan else TextSecondaryDark
                            )
                        }
                    )
                }
            }
        }

        // Summary Metric Cards
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Card(
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = DarkSurface)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("Average Score", style = MaterialTheme.typography.bodySmall, color = TextSecondaryDark)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text("${state.averageScore} / 100", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = SuccessGreen)
                        Text("+8% vs last week", fontSize = 11.sp, color = SuccessGreen)
                    }
                }

                Card(
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = DarkSurface)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("Best Day", style = MaterialTheme.typography.bodySmall, color = TextSecondaryDark)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(state.bestDay, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = AccentCyan)
                        Text("92/100 peak flow", fontSize = 11.sp, color = TextMutedDark)
                    }
                }
            }
        }

        // Category Breakdown Header
        item {
            Text(
                text = "Time by Category",
                style = MaterialTheme.typography.titleLarge,
                color = TextPrimaryDark
            )
        }

        if (state.categorySummaries.isEmpty()) {
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(14.dp),
                    colors = CardDefaults.cardColors(containerColor = DarkSurface)
                ) {
                    Text(
                        text = "Collecting usage data across categories...",
                        style = MaterialTheme.typography.bodySmall,
                        color = TextMutedDark,
                        modifier = Modifier.padding(16.dp)
                    )
                }
            }
        } else {
            items(state.categorySummaries) { summary ->
                val progress = if (state.totalScreenTimeMinutes > 0) {
                    (summary.totalMinutes.toFloat() / state.totalScreenTimeMinutes.toFloat()).coerceIn(0f, 1f)
                } else 0f

                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(14.dp),
                    colors = CardDefaults.cardColors(containerColor = DarkSurface)
                ) {
                    Column(modifier = Modifier.padding(14.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(
                                text = summary.category,
                                style = MaterialTheme.typography.titleMedium,
                                color = TextPrimaryDark
                            )
                            Text(
                                text = formatMinutes(summary.totalMinutes),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = TextPrimaryDark
                            )
                        }
                        Spacer(modifier = Modifier.height(8.dp))
                        LinearProgressIndicator(
                            progress = { progress },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(6.dp)
                                .clip(RoundedCornerShape(3.dp)),
                            color = when {
                                AppCategoryManager.isProductive(summary.category) -> SuccessGreen
                                AppCategoryManager.isDistracting(summary.category) -> DangerRed
                                else -> InfoBlue
                            },
                            trackColor = DarkCardBorder
                        )
                    }
                }
            }
        }
    }
}

private fun formatMinutes(minutes: Long): String {
    val hours = minutes / 60
    val mins = minutes % 60
    return if (hours > 0) "${hours}h ${mins}m" else "${mins}m"
}
