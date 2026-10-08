# FocusFlow ⏳📱
> **Take Control of Your Time. Take Control of Your Day.**

FocusFlow is a modern, privacy-focused, local-first Android time management and digital wellbeing application built with **Kotlin** and **Jetpack Compose**. It automatically tracks app usage on device, categorizes activities, scores daily productivity, manages deep focus sessions and Pomodoro timers, and provides AI-powered productivity recommendations with offline fallback.

---

## 🚀 Key Features

### 1. Automatic App Usage Tracking (Local-First)
- Uses Android's `UsageStatsManager` and `UsageEvents` to extract foreground time and app open counts.
- Stores historical usage in an encrypted on-device Room SQLite database.
- Completely functional with **Internet = OFF**.

### 2. Intelligent Categorization
- Automatically maps installed apps into 9 standard categories:
  - **Education**: Google Classroom, Coursera, Udemy, Duolingo, etc.
  - **Work**: Slack, Microsoft Teams, Zoom, Google Meet, Trello, etc.
  - **Social Media**: Instagram, Facebook, TikTok, X (Twitter), Reddit, etc.
  - **Entertainment**: YouTube, Netflix, Spotify, Disney+, etc.
  - **Communication**: WhatsApp, Messenger, Telegram, Signal, etc.
  - **Gaming**: PUBG, Free Fire, Roblox, Minecraft, etc.
  - **Browser**: Chrome, Firefox, Edge, etc.
  - **Productivity**: Notion, Google Keep, Calendar, Docs, etc.
  - **Other**
- Users can manually reclassify any application.

### 3. Productivity Scoring Engine (0 - 100)
Calculates a balanced daily score based on a transparent 5-pillar formula:
- **Goal Completion**: 30%
- **Productive Ratio**: 25% (Productive Time vs Total Active Time)
- **Focus Sessions**: 20% (Deep work minutes towards 120m daily target)
- **Distraction Control**: 15% (Penalizes excess entertainment & budget breaches)
- **Consistency / Streak**: 10% (Consecutive high-productivity days)

### 4. Deep Focus Mode & Customizable Pomodoro
- **Focus Mode**: Set custom tasks (e.g., "Database Assignment"), configure duration (25m to 120m), log distraction events, and view session summaries.
- **Pomodoro Timer**: Presets for Classic (25/5), Deep Work (50/10), Ultradian (90/15), and custom durations with cycle progress tracking.

### 5. Time Budgets & App Limits
- Set daily time budgets per category (e.g. Social Media max 60 mins).
- Set app-specific daily limits (e.g. YouTube max 60 mins).
- Proactive warning notifications trigger at 75%, 90%, and 100% threshold consumption.

### 6. Gamification: Streaks & Badges
- Continuous daily productivity streaks.
- Milestone achievement badges: *First Focus*, *Deep Worker (10h)*, *Momentum (3-day streak)*, *Unstoppable (7-day streak)*, *Digital Balance*, and *Goal Crusher*.

### 7. Offline-First AI Productivity Assistant
- **Local Heuristics Engine**: Generates schedules, analyzes low productivity days, and provides distraction reduction tips completely offline.
- **Privacy Aggregator**: Strips raw application names and personal info, anonymizing data before optional cloud Gemini processing.
- **Cloud Gemini Integration**: Optional connection to Gemini API for conversational coaching.

### 8. Privacy & Data Ownership
- Export all data to **CSV** and **JSON** anytime.
- Clear today's tracking or wipe all local database records with 1 tap.

---

## 🏛️ Architecture & Tech Stack

```
                          FOCUSFLOW
                              │
               ┌──────────────┴──────────────┐
               │                             │
          Android UI                     Background
        Jetpack Compose                  Processing
               │                             │
          ViewModels                    WorkManager
               │                             │
          Use Cases                          │
               │                             │
          Repository ────────────────────────┘
               │
        ┌──────┴───────┐
        │              │
    Room DB        AI Service
    (SQLite)           │
               ┌───────┴───────┐
               │               │
         Local Offline    Gemini API
           Heuristic       (Optional)
```

- **Language**: Kotlin 2.0.21
- **UI Framework**: Jetpack Compose with Material 3 Design
- **Architecture**: MVVM + Repository Pattern + Clean Architecture Use Cases
- **Local Database**: Room 2.6.1 (SQLite) with KSP
- **Background Tasks**: AndroidX WorkManager
- **System APIs**: `UsageStatsManager`, `NotificationManager`, `AppOpsManager`
- **Network / Serialization**: OkHttp 4.12, Gson 2.11

---

## 📂 Project Structure

```
com.focusflow.app
├── data
│   ├── local
│   │   ├── dao          # Room DAOs (AppUsageDao, GoalDao, BudgetDao, ScoreDao, etc.)
│   │   ├── database     # FocusFlowDatabase (SQLite singleton + Seed callbacks)
│   │   └── entities     # Room Entities (User, AppUsage, Goals, Budgets, etc.)
│   ├── remote
│   │   └── ai           # AIPrivacyAggregator & GeminiAIService
│   └── repository       # Repository layer (AppUsageRepository, GoalRepository, etc.)
├── domain
│   ├── usecase          # CalculateDailyScoreUseCase, EvaluateBudgetsUseCase
│   ├── AppCategoryManager.kt
│   ├── ProductivityScoreEngine.kt
│   ├── FocusModeManager.kt
│   ├── PomodoroEngine.kt
│   ├── StreakManager.kt
│   └── AchievementEngine.kt
├── presentation
│   ├── analytics        # Daily/Weekly/Monthly stats & charts
│   ├── achievements     # Badges grid & streak banner
│   ├── ai               # Conversational AI coach screen
│   ├── dashboard        # Circular score dial, metrics, today's goals
│   ├── focus            # Live Focus mode & Pomodoro timer
│   ├── goals            # Goals list & category budget sliders
│   ├── navigation       # Bottom Navigation Bar & NavHost
│   ├── settings         # Permissions, data export/delete
│   ├── theme            # Material 3 colors, typography, theme
│   └── usage            # Detailed app list & limit settings
├── services
│   ├── UsageTrackingManager.kt
│   └── DailyUsageAggregationWorker.kt
├── utils
│   ├── PermissionHelper.kt
│   ├── NotificationHelper.kt
│   └── DataExportManager.kt
├── FocusFlowApplication.kt
└── MainActivity.kt
```

---

## 📲 How to Build & Run

### Prerequisites
- Android Studio Ladybug / Iguana or newer
- JDK 17 or higher
- Android SDK 35 (minSdk 26)

### Build Steps
1. Open the project root folder in **Android Studio**.
2. Sync Gradle files.
3. Run on an Android emulator or physical device running Android 8.0+ (API 26+).
4. On first launch, open **Settings** or the prompt on the dashboard and tap **Grant** to enable Android's **Usage Access** permission so FocusFlow can track foreground app time.