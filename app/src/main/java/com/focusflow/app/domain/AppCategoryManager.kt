package com.focusflow.app.domain

object AppCategoryManager {

    const val CATEGORY_EDUCATION = "Education"
    const val CATEGORY_WORK = "Work"
    const val CATEGORY_SOCIAL = "Social Media"
    const val CATEGORY_ENTERTAINMENT = "Entertainment"
    const val CATEGORY_COMMUNICATION = "Communication"
    const val CATEGORY_GAMING = "Gaming"
    const val CATEGORY_BROWSER = "Browser"
    const val CATEGORY_PRODUCTIVITY = "Productivity"
    const val CATEGORY_OTHER = "Other"

    val ALL_CATEGORIES = listOf(
        CATEGORY_EDUCATION,
        CATEGORY_WORK,
        CATEGORY_PRODUCTIVITY,
        CATEGORY_SOCIAL,
        CATEGORY_ENTERTAINMENT,
        CATEGORY_GAMING,
        CATEGORY_COMMUNICATION,
        CATEGORY_BROWSER,
        CATEGORY_OTHER
    )

    private val defaultCategoryMap = mapOf(
        // Education
        "com.google.android.apps.classroom" to CATEGORY_EDUCATION,
        "org.coursera.android" to CATEGORY_EDUCATION,
        "com.udemy.android" to CATEGORY_EDUCATION,
        "com.duolingo" to CATEGORY_EDUCATION,
        "org.khanacademy.android" to CATEGORY_EDUCATION,

        // Work
        "com.slack" to CATEGORY_WORK,
        "com.microsoft.teams" to CATEGORY_WORK,
        "us.zoom.videomeetings" to CATEGORY_WORK,
        "com.google.android.apps.meetings" to CATEGORY_WORK,
        "com.trello" to CATEGORY_WORK,

        // Social Media
        "com.facebook.katana" to CATEGORY_SOCIAL,
        "com.facebook.lite" to CATEGORY_SOCIAL,
        "com.instagram.android" to CATEGORY_SOCIAL,
        "com.zhiliaoapp.musically" to CATEGORY_SOCIAL,
        "com.ss.android.ugc.trill" to CATEGORY_SOCIAL, // TikTok
        "com.twitter.android" to CATEGORY_SOCIAL,
        "com.snapchat.android" to CATEGORY_SOCIAL,
        "com.reddit.frontpage" to CATEGORY_SOCIAL,
        "com.pinterest" to CATEGORY_SOCIAL,

        // Entertainment
        "com.google.android.youtube" to CATEGORY_ENTERTAINMENT,
        "com.netflix.mediaclient" to CATEGORY_ENTERTAINMENT,
        "com.spotify.music" to CATEGORY_ENTERTAINMENT,
        "com.amazon.avod.thirdpartyclient" to CATEGORY_ENTERTAINMENT,
        "tv.twitch.android.app" to CATEGORY_ENTERTAINMENT,
        "com.disney.disneyplus" to CATEGORY_ENTERTAINMENT,

        // Communication
        "com.whatsapp" to CATEGORY_COMMUNICATION,
        "com.whatsapp.w4b" to CATEGORY_COMMUNICATION,
        "com.facebook.orca" to CATEGORY_COMMUNICATION,
        "org.telegram.messenger" to CATEGORY_COMMUNICATION,
        "org.thoughtcrime.securesms" to CATEGORY_COMMUNICATION,
        "com.google.android.apps.messaging" to CATEGORY_COMMUNICATION,

        // Gaming
        "com.tencent.ig" to CATEGORY_GAMING,
        "com.dts.freefireth" to CATEGORY_GAMING,
        "com.mobile.legends" to CATEGORY_GAMING,
        "com.roblox.client" to CATEGORY_GAMING,
        "com.mojang.minecraftpe" to CATEGORY_GAMING,
        "com.king.candycrushsaga" to CATEGORY_GAMING,

        // Browser
        "com.android.chrome" to CATEGORY_BROWSER,
        "org.mozilla.firefox" to CATEGORY_BROWSER,
        "com.microsoft.emmx" to CATEGORY_BROWSER,
        "com.sec.android.app.sbrowser" to CATEGORY_BROWSER,
        "com.opera.browser" to CATEGORY_BROWSER,

        // Productivity
        "notion.id" to CATEGORY_PRODUCTIVITY,
        "com.google.android.keep" to CATEGORY_PRODUCTIVITY,
        "com.google.android.calendar" to CATEGORY_PRODUCTIVITY,
        "com.google.android.apps.docs" to CATEGORY_PRODUCTIVITY,
        "com.google.android.apps.docs.editors.sheets" to CATEGORY_PRODUCTIVITY,
        "com.google.android.apps.docs.editors.slides" to CATEGORY_PRODUCTIVITY,
        "com.todoist" to CATEGORY_PRODUCTIVITY,
        "com.microsoft.todos" to CATEGORY_PRODUCTIVITY
    )

    fun getCategoryForPackage(packageName: String, userCustomMap: Map<String, String> = emptyMap()): String {
        // User custom categorization takes priority
        userCustomMap[packageName]?.let { return it }

        // Default mapped categories
        defaultCategoryMap[packageName]?.let { return it }

        // Heuristic detection based on package naming
        val lower = packageName.lowercase()
        return when {
            lower.contains("game") || lower.contains("play") -> CATEGORY_GAMING
            lower.contains("study") || lower.contains("learn") || lower.contains("edu") -> CATEGORY_EDUCATION
            lower.contains("social") || lower.contains("chat") -> CATEGORY_SOCIAL
            lower.contains("browser") -> CATEGORY_BROWSER
            lower.contains("media") || lower.contains("video") || lower.contains("music") -> CATEGORY_ENTERTAINMENT
            lower.contains("office") || lower.contains("notes") || lower.contains("task") -> CATEGORY_PRODUCTIVITY
            else -> CATEGORY_OTHER
        }
    }

    fun isProductive(category: String): Boolean {
        return category == CATEGORY_EDUCATION || category == CATEGORY_WORK || category == CATEGORY_PRODUCTIVITY
    }

    fun isDistracting(category: String): Boolean {
        return category == CATEGORY_SOCIAL || category == CATEGORY_ENTERTAINMENT || category == CATEGORY_GAMING
    }
}
