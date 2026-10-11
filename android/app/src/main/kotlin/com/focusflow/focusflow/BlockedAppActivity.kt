package com.focusflow.focusflow

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

class BlockedAppActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val blockedPackage = intent.getStringExtra("blockedPackage") ?: ""
        val blockedAppName = intent.getStringExtra("blockedAppName") ?: "This App"
        val usedMinutes = intent.getIntExtra("usedMinutes", 0)
        val limitMinutes = intent.getIntExtra("limitMinutes", 0)

        // Root Layout
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#0F172A")) // Modern deep navy/slate
            setPadding(64, 80, 64, 80)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        // App Icon or Lock Symbol
        val iconView = ImageView(this).apply {
            try {
                if (blockedPackage.isNotEmpty()) {
                    val iconDrawable = packageManager.getApplicationIcon(blockedPackage)
                    setImageDrawable(iconDrawable)
                } else {
                    setImageResource(android.R.drawable.ic_lock_power_off)
                }
            } catch (_: Exception) {
                setImageResource(android.R.drawable.ic_lock_power_off)
            }
            layoutParams = LinearLayout.LayoutParams(180, 180).apply {
                bottomMargin = 48
            }
        }
        root.addView(iconView)

        // Title
        val titleText = TextView(this).apply {
            text = "Time's Up!"
            textSize = 28f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 16
            }
        }
        root.addView(titleText)

        // Subtitle with app name
        val subText = TextView(this).apply {
            text = "Daily limit reached for $blockedAppName"
            textSize = 17f
            setTextColor(Color.parseColor("#94A3B8")) // Slate 400
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 36
            }
        }
        root.addView(subText)

        // Card displaying usage vs limit
        val statsCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            val cardBg = GradientDrawable().apply {
                setColor(Color.parseColor("#1E293B"))
                cornerRadius = 32f
                setStroke(2, Color.parseColor("#334155"))
            }
            background = cardBg
            setPadding(48, 36, 48, 36)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 54
            }
        }

        val limitDetail = TextView(this).apply {
            val h = usedMinutes / 60
            val m = usedMinutes % 60
            val timeUsedStr = if (h > 0) "${h}h ${m}m" else "${m}m"
            text = "Used: $timeUsedStr / Limit: ${limitMinutes}m"
            textSize = 16f
            setTextColor(Color.parseColor("#38BDF8")) // Cyan
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        statsCard.addView(limitDetail)

        val adviceText = TextView(this).apply {
            text = "Take a break! Protect your focus & stay productive today."
            textSize = 13f
            setTextColor(Color.parseColor("#CBD5E1"))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = 12
            }
        }
        statsCard.addView(adviceText)
        root.addView(statsCard)

        // Return to FocusFlow Button
        val focusFlowBtn = Button(this).apply {
            text = "Open FocusFlow"
            textSize = 15f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            val btnBg = GradientDrawable().apply {
                setColor(Color.parseColor("#4F46E5")) // Primary indigo
                cornerRadius = 24f
            }
            background = btnBg
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                130
            ).apply {
                bottomMargin = 24
            }
            setOnClickListener {
                val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                if (launchIntent != null) {
                    launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    startActivity(launchIntent)
                }
                finish()
            }
        }
        root.addView(focusFlowBtn)

        // Home Button
        val homeBtn = Button(this).apply {
            text = "Go to Home Screen"
            textSize = 14f
            setTextColor(Color.parseColor("#94A3B8"))
            val borderBg = GradientDrawable().apply {
                setColor(Color.TRANSPARENT)
                cornerRadius = 24f
                setStroke(2, Color.parseColor("#475569"))
            }
            background = borderBg
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                120
            )
            setOnClickListener {
                val startMain = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(startMain)
                finish()
            }
        }
        root.addView(homeBtn)

        setContentView(root)
    }

    override fun onBackPressed() {
        // Prevent going back into the blocked app
        val startMain = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(startMain)
        finish()
    }
}
