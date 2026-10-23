package com.focusflow.focusflow

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.CountDownTimer
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast

class BlockedAppActivity : Activity() {

    private var countdownTimer: CountDownTimer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val blockedPackage = intent.getStringExtra("blockedPackage") ?: ""
        val blockedAppName = intent.getStringExtra("blockedAppName") ?: "This App"
        val usedMinutes = intent.getIntExtra("usedMinutes", 0)
        val limitMinutes = intent.getIntExtra("limitMinutes", 0)

        val prefs = getSharedPreferences(AppBlockerService.PREFS_NAME, Context.MODE_PRIVATE)
        val isStrictMode = prefs.getBoolean("strict_lock_enabled", false)

        val scroll = ScrollView(this).apply {
            setBackgroundColor(Color.parseColor("#090D16")) // Ultra-dark modern slate
            isFillViewport = true
        }

        // Root Layout
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(56, 64, 56, 64)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
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
            layoutParams = LinearLayout.LayoutParams(170, 170).apply {
                bottomMargin = 36
                gravity = Gravity.CENTER_HORIZONTAL
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
                bottomMargin = 10
            }
        }
        root.addView(titleText)

        // Subtitle with app name
        val subText = TextView(this).apply {
            text = "Daily limit reached for $blockedAppName"
            textSize = 15f
            setTextColor(Color.parseColor("#94A3B8")) // Slate 400
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 28
            }
        }
        root.addView(subText)

        // Card displaying usage vs limit
        val statsCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            val cardBg = GradientDrawable().apply {
                setColor(Color.parseColor("#151A28"))
                cornerRadius = 28f
                setStroke(2, Color.parseColor("#263045"))
            }
            background = cardBg
            setPadding(40, 28, 40, 28)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 28
            }
        }

        val limitDetail = TextView(this).apply {
            val h = usedMinutes / 60
            val m = usedMinutes % 60
            val timeUsedStr = if (h > 0) "${h}h ${m}m" else "${m}m"
            text = "Used: $timeUsedStr / Limit: ${limitMinutes}m"
            textSize = 15f
            setTextColor(Color.parseColor("#00CEC9")) // Electric Cyan
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        statsCard.addView(limitDetail)

        val adviceText = TextView(this).apply {
            text = "Protect your focus and preserve your daily streak."
            textSize = 12f
            setTextColor(Color.parseColor("#94A3B8"))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = 8
            }
        }
        statsCard.addView(adviceText)
        root.addView(statsCard)

        // Hardcore Strict Mode banner OR Friction Challenge
        if (isStrictMode) {
            val strictBanner = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                val bannerBg = GradientDrawable().apply {
                    setColor(Color.parseColor("#2A1215"))
                    cornerRadius = 24f
                    setStroke(2, Color.parseColor("#EF4444"))
                }
                background = bannerBg
                setPadding(32, 24, 32, 24)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    bottomMargin = 28
                }
            }

            val strictTitle = TextView(this).apply {
                text = "🔒 Hardcore Strict Lock Active"
                textSize = 14f
                setTextColor(Color.parseColor("#FCA5A5"))
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
            }
            strictBanner.addView(strictTitle)

            val strictDesc = TextView(this).apply {
                text = "Emergency pass is disabled to guarantee zero habit compromise."
                textSize = 11f
                setTextColor(Color.parseColor("#F87171"))
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = 4
                }
            }
            strictBanner.addView(strictDesc)
            root.addView(strictBanner)
        } else {
            // Container for Friction Challenge
            val challengeContainer = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                visibility = View.GONE
                val boxBg = GradientDrawable().apply {
                    setColor(Color.parseColor("#171D2F"))
                    cornerRadius = 28f
                    setStroke(2, Color.parseColor("#6C5CE7"))
                }
                background = boxBg
                setPadding(36, 28, 36, 28)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    bottomMargin = 28
                }
            }

            // Math problem generator
            val numA = (18..65).random()
            val numB = (14..48).random()
            val expectedSum = numA + numB

            val challengeTitle = TextView(this).apply {
                text = "⚡ Friction Challenge (5m Pass)"
                textSize = 14f
                setTextColor(Color.parseColor("#A29BFE"))
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
            }
            challengeContainer.addView(challengeTitle)

            val mathPrompt = TextView(this).apply {
                text = "Solve arithmetic to prove active consciousness:\n$numA + $numB = ?"
                textSize = 13f
                setTextColor(Color.WHITE)
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = 12
                    bottomMargin = 16
                }
            }
            challengeContainer.addView(mathPrompt)

            val answerInput = EditText(this).apply {
                hint = "Enter answer"
                setHintTextColor(Color.parseColor("#64748B"))
                setTextColor(Color.WHITE)
                textSize = 16f
                gravity = Gravity.CENTER
                inputType = InputType.TYPE_CLASS_NUMBER
                val inputBg = GradientDrawable().apply {
                    setColor(Color.parseColor("#0F1422"))
                    cornerRadius = 16f
                    setStroke(2, Color.parseColor("#334155"))
                }
                background = inputBg
                setPadding(24, 20, 24, 20)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    bottomMargin = 16
                }
            }
            challengeContainer.addView(answerInput)

            val verifyBtn = Button(this).apply {
                text = "Verify & Unlock 5m Pass"
                textSize = 13f
                setTextColor(Color.WHITE)
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                val btnBg = GradientDrawable().apply {
                    setColor(Color.parseColor("#6C5CE7"))
                    cornerRadius = 20f
                }
                background = btnBg
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    110
                )
                setOnClickListener {
                    val inputVal = answerInput.text.toString().trim().toIntOrNull()
                    if (inputVal == expectedSum) {
                        grantPassAndLaunch(blockedPackage, blockedAppName)
                    } else {
                        Toast.makeText(this@BlockedAppActivity, "Incorrect answer. Take a breath!", Toast.LENGTH_SHORT).show()
                        answerInput.setText("")
                    }
                }
            }
            challengeContainer.addView(verifyBtn)

            // Or 20s Mindful Pause Option
            val pauseBtn = Button(this).apply {
                text = "🧘 Or Take a 20s Mindful Pause"
                textSize = 12f
                setTextColor(Color.parseColor("#00CEC9"))
                val borderBg = GradientDrawable().apply {
                    setColor(Color.TRANSPARENT)
                    cornerRadius = 20f
                    setStroke(1, Color.parseColor("#00CEC9"))
                }
                background = borderBg
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    100
                ).apply {
                    topMargin = 12
                }
                setOnClickListener {
                    isEnabled = false
                    var secondsLeft = 20
                    text = "Breathe in... ($secondsLeft s)"
                    countdownTimer = object : CountDownTimer(20000, 1000) {
                        override fun onTick(millisUntilFinished: Long) {
                            secondsLeft = (millisUntilFinished / 1000).toInt()
                            val prompt = if (secondsLeft % 8 >= 4) "Breathe in..." else "Breathe out..."
                            text = "$prompt ($secondsLeft s)"
                        }

                        override fun onFinish() {
                            text = "Mindful Pause Complete!"
                            grantPassAndLaunch(blockedPackage, blockedAppName)
                        }
                    }.start()
                }
            }
            challengeContainer.addView(pauseBtn)
            root.addView(challengeContainer)

            // Trigger Button for Friction Challenge
            val emergencyBtn = Button(this).apply {
                text = "⚡ Emergency Pass (5 Min Challenge)"
                textSize = 13f
                setTextColor(Color.parseColor("#00CEC9"))
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                val borderBg = GradientDrawable().apply {
                    setColor(Color.parseColor("#0E2A36"))
                    cornerRadius = 22f
                    setStroke(2, Color.parseColor("#00CEC9"))
                }
                background = borderBg
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    120
                ).apply {
                    bottomMargin = 24
                }
                setOnClickListener {
                    visibility = View.GONE
                    challengeContainer.visibility = View.VISIBLE
                }
            }
            root.addView(emergencyBtn)
        }

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
                125
            ).apply {
                bottomMargin = 16
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
                setStroke(2, Color.parseColor("#334155"))
            }
            background = borderBg
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                115
            )
            setOnClickListener {
                goToHomeScreen()
            }
        }
        root.addView(homeBtn)

        scroll.addView(root)
        setContentView(scroll)
    }

    private fun grantPassAndLaunch(blockedPackage: String, blockedAppName: String) {
        val prefs = getSharedPreferences(AppBlockerService.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putLong("temp_unlock_$blockedPackage", System.currentTimeMillis() + 5 * 60 * 1000L).apply()

        Toast.makeText(this, "5-Minute Emergency Pass Granted for $blockedAppName", Toast.LENGTH_LONG).show()

        val launchIntent = packageManager.getLaunchIntentForPackage(blockedPackage)
        if (launchIntent != null) {
            launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            startActivity(launchIntent)
        }
        finish()
    }

    private fun goToHomeScreen() {
        val startMain = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(startMain)
        finish()
    }

    override fun onDestroy() {
        countdownTimer?.cancel()
        super.onDestroy()
    }

    override fun onBackPressed() {
        goToHomeScreen()
    }
}
