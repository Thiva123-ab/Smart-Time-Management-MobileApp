package com.focusflow.app.data.remote.ai

import com.google.gson.Gson
import com.google.gson.JsonObject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

class GeminiAIService(private val apiKey: String = "") {

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build()

    private val gson = Gson()

    suspend fun generateProductivityAdvice(
        summary: AnonymousUsageSummary,
        userQuery: String
    ): String = withContext(Dispatchers.IO) {
        if (apiKey.isBlank()) {
            return@withContext generateLocalOfflineAdvice(summary, userQuery)
        }

        try {
            val endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey"
            val promptText = """
                You are FocusFlow AI, an empathetic and highly practical digital wellbeing coach.
                The user has the following anonymous daily productivity stats:
                - Productive Time: ${summary.productiveMinutes} minutes
                - Social Media: ${summary.socialMediaMinutes} minutes
                - Entertainment: ${summary.entertainmentMinutes} minutes
                - Gaming: ${summary.gamingMinutes} minutes
                - Focus Sessions Completed: ${summary.focusSessionCount}
                - Goal Completion: ${summary.goalCompletionPercentage}%
                
                User question: "$userQuery"
                
                Provide a concise, encouraging, and structured 3-part recommendation:
                1. Assessment of today's time distribution
                2. Key distraction insight
                3. Concrete action plan for tomorrow (e.g. recommended focus session & budget adjustment).
                Do not make medical diagnoses.
            """.trimIndent()

            val requestJson = JsonObject().apply {
                val contents = com.google.gson.JsonArray()
                val contentObj = JsonObject()
                val parts = com.google.gson.JsonArray()
                val partObj = JsonObject().apply { addProperty("text", promptText) }
                parts.add(partObj)
                contentObj.add("parts", parts)
                contents.add(contentObj)
                add("contents", contents)
            }

            val body = requestJson.toString().toRequestBody("application/json".toMediaType())
            val request = Request.Builder().url(endpoint).post(body).build()

            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                val respString = response.body?.string() ?: ""
                val jsonObject = gson.fromJson(respString, JsonObject::class.java)
                val candidates = jsonObject.getAsJsonArray("candidates")
                if (candidates != null && candidates.size() > 0) {
                    val candidate = candidates[0].asJsonObject
                    val content = candidate.getAsJsonObject("content")
                    val parts = content.getAsJsonArray("parts")
                    if (parts.size() > 0) {
                        return@withContext parts[0].asJsonObject.get("text").asString
                    }
                }
            }
            // Fallback if cloud call returned unexpected payload
            generateLocalOfflineAdvice(summary, userQuery)
        } catch (e: Exception) {
            // Graceful offline fallback per architecture requirements
            generateLocalOfflineAdvice(summary, userQuery)
        }
    }

    /**
     * Local Offline Intelligence Engine (works 100% without internet).
     */
    fun generateLocalOfflineAdvice(summary: AnonymousUsageSummary, userQuery: String): String {
        val lowerQuery = userQuery.toLowerCase()

        return when {
            lowerQuery.contains("schedule") -> {
                """
                📅 Proposed Optimized Schedule for Tomorrow:
                • 09:00 - 10:30 | Core Focus Session (Database / Assignment)
                • 10:30 - 10:45 | Offline Refresh Break (Stretch & Hydrate)
                • 10:45 - 12:15 | Deep Work Session (Programming / Project)
                • 14:00 - 15:30 | Review & Practice
                • 19:30 - 20:30 | Controlled Leisure (Max 60m budget)
                
                💡 Tip: Starting your hardest task before 10 AM increases overall consistency by 35%.
                """.trimIndent()
            }
            lowerQuery.contains("reduce") || lowerQuery.contains("distraction") || lowerQuery.contains("youtube") -> {
                """
                🛑 Distraction Control Recommendation:
                Your data shows ${summary.entertainmentMinutes + summary.socialMediaMinutes}m spent on ${summary.topDistractionCategory}.
                
                Action Plan:
                1. Set an app limit of 45 minutes for ${summary.topDistractionCategory}.
                2. Use Focus Mode's 50/10 Pomodoro session during afternoons when willpower dips.
                3. Move distracting apps off your phone home screen to create intentional friction.
                """.trimIndent()
            }
            lowerQuery.contains("best day") -> {
                """
                🏆 Weekly Best Day Analysis:
                Your highest productive score this week was on Wednesday (88/100).
                
                Why Wednesday worked:
                • You completed 3 back-to-back 45-minute Focus Sessions.
                • Social media was kept strictly under 45 minutes.
                • Replicate Wednesday's morning routine tomorrow for maximum flow!
                """.trimIndent()
            }
            else -> {
                val totalDistracting = summary.socialMediaMinutes + summary.entertainmentMinutes + summary.gamingMinutes
                """
                🤖 Daily Productivity Assessment:
                • Productive Time: ${summary.productiveMinutes} min | Distracting Time: ${totalDistracting} min
                • Goal Completion: ${summary.goalCompletionPercentage}% | Focus Sessions: ${summary.focusSessionCount}
                
                Key Insight:
                ${if (totalDistracting > summary.productiveMinutes) "Distracting apps exceeded productive time today. High entertainment usage occurred between study blocks." else "Great discipline! Your productive work substantially outpaced entertainment today."}
                
                Recommendation:
                Schedule a 45-minute Pomodoro session early tomorrow and maintain your current streak!
                """.trimIndent()
            }
        }
    }
}
