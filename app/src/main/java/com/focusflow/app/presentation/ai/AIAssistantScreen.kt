package com.focusflow.app.presentation.ai

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.focusflow.app.presentation.theme.*

@Composable
fun AIAssistantScreen(
    viewModel: AIViewModel,
    onNavigateBack: () -> Unit
) {
    val state by viewModel.uiState.collectAsState()
    var inputQuery by remember { mutableStateOf("") }

    val promptSuggestions = listOf(
        "Analyze my productivity",
        "Create tomorrow's schedule",
        "How to reduce distracting apps?",
        "What was my best day this week?"
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBackground)
    ) {
        // Top Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onNavigateBack) {
                Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = TextPrimaryDark)
            }
            Spacer(modifier = Modifier.width(8.dp))
            Column {
                Text("FocusFlow AI 🤖", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = TextPrimaryDark)
                Text("Offline-first privacy preserving assistant", style = MaterialTheme.typography.bodySmall, color = TextSecondaryDark)
            }
        }

        // Chat Message List
        LazyColumn(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            contentPadding = PaddingValues(vertical = 12.dp)
        ) {
            items(state.messages) { msg ->
                val isUser = msg.sender == "USER"
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start
                ) {
                    Box(
                        modifier = Modifier
                            .widthIn(max = 300.dp)
                            .clip(
                                RoundedCornerShape(
                                    topStart = 16.dp,
                                    topEnd = 16.dp,
                                    bottomStart = if (isUser) 16.dp else 4.dp,
                                    bottomEnd = if (isUser) 4.dp else 16.dp
                                )
                            )
                            .background(if (isUser) PrimaryPurple else DarkSurface)
                            .padding(14.dp)
                    ) {
                        Text(
                            text = msg.message,
                            color = TextPrimaryDark,
                            style = MaterialTheme.typography.bodyMedium,
                            lineHeight = 20.sp
                        )
                    }
                }
            }

            if (state.isThinking) {
                item {
                    Text(
                        text = "FocusFlow AI is analyzing your data...",
                        style = MaterialTheme.typography.bodySmall,
                        color = AccentCyan
                    )
                }
            }
        }

        // Suggestions Row
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp)
        ) {
            items(promptSuggestions) { suggestion ->
                AssistChip(
                    onClick = { viewModel.askAI(suggestion) },
                    label = { Text(suggestion, fontSize = 11.sp) },
                    colors = AssistChipDefaults.assistChipColors(
                        containerColor = DarkSurface,
                        labelColor = AccentCyan
                    ),
                    shape = RoundedCornerShape(16.dp)
                )
            }
        }

        // Bottom Input Field
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = inputQuery,
                onValueChange = { inputQuery = it },
                placeholder = { Text("Ask FocusFlow AI...", color = TextMutedDark) },
                singleLine = true,
                modifier = Modifier.weight(1f),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = PrimaryPurple,
                    unfocusedBorderColor = DarkCardBorder,
                    focusedTextColor = TextPrimaryDark,
                    unfocusedTextColor = TextPrimaryDark,
                    focusedContainerColor = DarkSurface,
                    unfocusedContainerColor = DarkSurface
                ),
                shape = RoundedCornerShape(24.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            IconButton(
                onClick = {
                    if (inputQuery.isNotBlank()) {
                        viewModel.askAI(inputQuery)
                        inputQuery = ""
                    }
                },
                modifier = Modifier
                    .clip(RoundedCornerShape(20.dp))
                    .background(PrimaryPurple)
            ) {
                Icon(Icons.Default.Send, contentDescription = "Send", tint = Color.White)
            }
        }
    }
}
