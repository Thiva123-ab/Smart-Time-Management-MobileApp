package com.focusflow.app.presentation.focus

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.WarningAmber
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.focusflow.app.domain.PomodoroEngine
import com.focusflow.app.domain.PomodoroPhase
import com.focusflow.app.presentation.theme.*

@Composable
fun FocusScreen(viewModel: FocusViewModel) {
    var selectedTab by remember { mutableIntStateOf(0) }
    val focusState by viewModel.focusState.collectAsState()
    val pomodoroState by viewModel.pomodoroState.collectAsState()
    val summary by viewModel.lastSummary.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBackground)
            .padding(horizontal = 20.dp)
            .padding(top = 24.dp)
    ) {
        Text(
            text = "Focus & Flow",
            style = MaterialTheme.typography.headlineLarge,
            color = TextPrimaryDark
        )
        Text(
            text = "Enter deep work and track your uninterrupted sessions",
            style = MaterialTheme.typography.bodyMedium,
            color = TextSecondaryDark
        )

        Spacer(modifier = Modifier.height(18.dp))

        // Tab Selector (Focus Session vs Pomodoro)
        TabRow(
            selectedTabIndex = selectedTab,
            containerColor = DarkSurface,
            contentColor = PrimaryPurple,
            indicator = {},
            divider = {},
            modifier = Modifier.clip(RoundedCornerShape(14.dp))
        ) {
            Tab(
                selected = selectedTab == 0,
                onClick = { selectedTab = 0 },
                text = { Text("Focus Session", fontWeight = FontWeight.Bold, color = if (selectedTab == 0) AccentCyan else TextSecondaryDark) }
            )
            Tab(
                selected = selectedTab == 1,
                onClick = { selectedTab = 1 },
                text = { Text("Pomodoro Timer", fontWeight = FontWeight.Bold, color = if (selectedTab == 1) AccentCyan else TextSecondaryDark) }
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        if (selectedTab == 0) {
            FocusSessionTab(
                state = focusState,
                onStart = { task, mins -> viewModel.startFocusSession(task, mins) },
                onPause = { viewModel.pauseFocus() },
                onResume = { viewModel.resumeFocus() },
                onRecordDistraction = { viewModel.recordDistraction() },
                onFinish = { viewModel.finishFocusSession(true) }
            )
        } else {
            PomodoroTab(
                state = pomodoroState,
                onStart = { viewModel.startPomodoro() },
                onPause = { viewModel.pausePomodoro() },
                onReset = { viewModel.resetPomodoro() },
                onSelectPreset = { viewModel.applyPreset(it) }
            )
        }
    }

    // Session Completed Dialog
    summary?.let { s ->
        AlertDialog(
            onDismissRequest = { viewModel.dismissSummary() },
            title = {
                Text("🎉 Focus Complete!", color = TextPrimaryDark, fontWeight = FontWeight.Bold)
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Task: ${s.taskName}", color = TextPrimaryDark, fontWeight = FontWeight.SemiBold)
                    Text("Planned: ${s.plannedMinutes} mins", color = TextSecondaryDark)
                    Text("Completed: ${s.completedMinutes} mins", color = SuccessGreen, fontWeight = FontWeight.Bold)
                    Text("Distractions logged: ${s.distractionCount}", color = if (s.distractionCount > 2) DangerRed else TextSecondaryDark)
                }
            },
            confirmButton = {
                Button(
                    onClick = { viewModel.dismissSummary() },
                    colors = ButtonDefaults.buttonColors(containerColor = PrimaryPurple)
                ) {
                    Text("Done")
                }
            },
            containerColor = DarkSurface
        )
    }
}

@Composable
fun FocusSessionTab(
    state: com.focusflow.app.domain.FocusSessionState,
    onStart: (String, Long) -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onRecordDistraction: () -> Unit,
    onFinish: () -> Unit
) {
    var taskInput by remember { mutableStateOf("Deep Study") }
    var durationMinutes by remember { mutableLongStateOf(25L) }

    if (!state.isActive) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = DarkSurface)
            ) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Text("Configure Session", style = MaterialTheme.typography.titleMedium, color = TextPrimaryDark)
                    Spacer(modifier = Modifier.height(14.dp))
                    OutlinedTextField(
                        value = taskInput,
                        onValueChange = { taskInput = it },
                        label = { Text("Task / Project Name") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = PrimaryPurple,
                            unfocusedBorderColor = DarkCardBorder,
                            focusedTextColor = TextPrimaryDark,
                            unfocusedTextColor = TextPrimaryDark
                        )
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text("Session Length", style = MaterialTheme.typography.bodySmall, color = TextSecondaryDark)
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        listOf(25L, 45L, 60L, 90L, 120L).forEach { mins ->
                            Button(
                                onClick = { durationMinutes = mins },
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = if (durationMinutes == mins) PrimaryPurple else DarkSurfaceVariant
                                ),
                                shape = RoundedCornerShape(12.dp),
                                modifier = Modifier.weight(1f),
                                contentPadding = PaddingValues(horizontal = 4.dp, vertical = 8.dp)
                            ) {
                                Text("${mins}m", fontSize = 12.sp, color = TextPrimaryDark)
                            }
                        }
                    }
                }
            }

            Button(
                onClick = { onStart(taskInput, durationMinutes) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ButtonDefaults.buttonColors(containerColor = PrimaryPurple),
                shape = RoundedCornerShape(16.dp)
            ) {
                Icon(Icons.Default.PlayArrow, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("Start Focus Session ($durationMinutes mins)", fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
        }
    } else {
        // Active Session View
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            Text(
                text = state.taskName,
                style = MaterialTheme.typography.headlineMedium,
                color = TextPrimaryDark
            )

            val totalSec = state.plannedMinutes * 60
            val remainingSec = (totalSec - state.elapsedSeconds).coerceAtLeast(0)
            val minutesLeft = remainingSec / 60
            val secondsLeft = remainingSec % 60
            val progress = (state.elapsedSeconds.toFloat() / totalSec.toFloat()).coerceIn(0f, 1f)

            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(220.dp)
                    .clip(CircleShape)
                    .background(DarkSurface)
            ) {
                CircularProgressIndicator(
                    progress = { progress },
                    modifier = Modifier.fillMaxSize(),
                    strokeWidth = 12.dp,
                    color = AccentCyan,
                    trackColor = DarkCardBorder
                )
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = String.format("%02d:%02d", minutesLeft, secondsLeft),
                        style = MaterialTheme.typography.headlineLarge,
                        fontSize = 42.sp,
                        fontWeight = FontWeight.Bold,
                        color = TextPrimaryDark
                    )
                    Text(
                        text = "Distractions: ${state.distractionCount}",
                        style = MaterialTheme.typography.bodySmall,
                        color = if (state.distractionCount > 0) WarningOrange else TextSecondaryDark
                    )
                }
            }

            // Distraction logging button
            OutlinedButton(
                onClick = onRecordDistraction,
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.outlinedButtonColors(contentColor = WarningOrange)
            ) {
                Icon(Icons.Default.WarningAmber, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("Log Distraction (+1)")
            }

            // Session controls
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Button(
                    onClick = if (state.isPaused) onResume else onPause,
                    modifier = Modifier.weight(1f).height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = if (state.isPaused) SuccessGreen else WarningOrange),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    Text(if (state.isPaused) "Resume" else "Pause", fontWeight = FontWeight.Bold)
                }
                Button(
                    onClick = onFinish,
                    modifier = Modifier.weight(1f).height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = DangerRed),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    Icon(Icons.Default.Stop, contentDescription = null)
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Complete", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
fun PomodoroTab(
    state: com.focusflow.app.domain.PomodoroState,
    onStart: () -> Unit,
    onPause: () -> Unit,
    onReset: () -> Unit,
    onSelectPreset: (com.focusflow.app.domain.PomodoroPreset) -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        // Presets selector
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            listOf(PomodoroEngine.PRESET_25_5, PomodoroEngine.PRESET_50_10, PomodoroEngine.PRESET_90_15).forEach { preset ->
                OutlinedButton(
                    onClick = { onSelectPreset(preset) },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = if (state.focusDurationMinutes == preset.focusMinutes) PrimaryPurple.copy(alpha = 0.2f) else DarkSurface
                    )
                ) {
                    Text(preset.title, fontSize = 11.sp, color = TextPrimaryDark)
                }
            }
        }

        // Current phase badge
        val phaseLabel = when (state.currentPhase) {
            PomodoroPhase.FOCUS -> "🎯 FOCUS PERIOD"
            PomodoroPhase.SHORT_BREAK -> "☕ SHORT BREAK"
            PomodoroPhase.LONG_BREAK -> "🌴 LONG BREAK"
        }
        val phaseColor = when (state.currentPhase) {
            PomodoroPhase.FOCUS -> PrimaryPurple
            PomodoroPhase.SHORT_BREAK -> AccentCyan
            PomodoroPhase.LONG_BREAK -> SuccessGreen
        }

        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(20.dp))
                .background(phaseColor.copy(alpha = 0.2f))
                .padding(horizontal = 16.dp, vertical = 6.dp)
        ) {
            Text(phaseLabel, color = phaseColor, fontWeight = FontWeight.Bold, fontSize = 12.sp)
        }

        // Circular timer
        val totalSec = when (state.currentPhase) {
            PomodoroPhase.FOCUS -> state.focusDurationMinutes * 60
            PomodoroPhase.SHORT_BREAK -> state.breakDurationMinutes * 60
            PomodoroPhase.LONG_BREAK -> state.longBreakDurationMinutes * 60
        }
        val minutes = state.remainingSeconds / 60
        val seconds = state.remainingSeconds % 60
        val progress = if (totalSec > 0) (state.remainingSeconds.toFloat() / totalSec.toFloat()) else 0f

        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(220.dp)
                .clip(CircleShape)
                .background(DarkSurface)
        ) {
            CircularProgressIndicator(
                progress = { progress },
                modifier = Modifier.fillMaxSize(),
                strokeWidth = 12.dp,
                color = phaseColor,
                trackColor = DarkCardBorder
            )
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = String.format("%02d:%02d", minutes, seconds),
                    style = MaterialTheme.typography.headlineLarge,
                    fontSize = 44.sp,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimaryDark
                )
                Text(
                    text = "Cycle #${state.completedCycles + 1}",
                    style = MaterialTheme.typography.bodySmall,
                    color = TextSecondaryDark
                )
            }
        }

        // Controls
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Button(
                onClick = if (state.isRunning) onPause else onStart,
                modifier = Modifier.weight(1f).height(50.dp),
                colors = ButtonDefaults.buttonColors(containerColor = if (state.isRunning) WarningOrange else PrimaryPurple),
                shape = RoundedCornerShape(14.dp)
            ) {
                Text(if (state.isRunning) "Pause" else "Start", fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
            IconButton(
                onClick = onReset,
                modifier = Modifier
                    .size(50.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(DarkSurfaceVariant)
            ) {
                Icon(Icons.Default.Refresh, contentDescription = "Reset", tint = TextPrimaryDark)
            }
        }
    }
}
