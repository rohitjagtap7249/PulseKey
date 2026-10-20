package com.rohitjagtap.pulsekey

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextClock
import android.widget.TextView

class AlarmActivity : Activity() {

    private val handler = Handler(Looper.getMainLooper())
    private val poll = object : Runnable {
        override fun run() {
            if (TimerStore.state(this@AlarmActivity) != TimerStore.RINGING) {
                finish()
                return
            }
            handler.postDelayed(this, 500)
        }
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val root = LinearLayout(this)
        root.orientation = LinearLayout.VERTICAL
        root.gravity = Gravity.CENTER_HORIZONTAL
        root.background = GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(
                Color.parseColor("#0B0406"),
                Color.parseColor("#140607"),
                Color.parseColor("#7A2418")
            )
        )
        root.setPadding(0, dp(24), 0, dp(40))

        root.addView(spacer(1f))

        val clock = TextClock(this)
        clock.format12Hour = "h:mm"
        clock.format24Hour = "H:mm"
        clock.textSize = 88f
        clock.setTextColor(Color.parseColor("#E8E1E1"))
        clock.typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
        clock.gravity = Gravity.CENTER
        root.addView(clock)

        val date = TextClock(this)
        date.format12Hour = "EEEE, d MMMM"
        date.format24Hour = "EEEE, d MMMM"
        date.textSize = 18f
        date.setTextColor(Color.parseColor("#9A9090"))
        date.gravity = Gravity.CENTER
        root.addView(date)

        root.addView(spacer(1f))

        val title = TextView(this)
        title.text = "Time's up"
        title.textSize = 38f
        title.setTextColor(Color.WHITE)
        title.gravity = Gravity.CENTER
        root.addView(title)

        val sub = TextView(this)
        sub.text = "Timer  \u2022  " + describe(TimerStore.durationMs(this))
        sub.textSize = 18f
        sub.setTextColor(Color.parseColor("#9A9090"))
        sub.gravity = Gravity.CENTER
        root.addView(sub)

        root.addView(pill("Repeat", "#EB3B2F", "#FFFFFF", AlarmService.ACTION_REPEAT))

        root.addView(spacer(3f))

        root.addView(pill("Stop", "#F1E8E6", "#1C1B1B", AlarmService.ACTION_STOP))

        setContentView(root)
    }

    private fun describe(ms: Long): String {
        val totalMin = ms / 60000L
        val h = totalMin / 60L
        val m = totalMin % 60L
        return when {
            h > 0L && m > 0L -> "$h h $m min"
            h > 0L -> "$h h"
            else -> "$m min"
        }
    }

    private fun spacer(weight: Float): View {
        val v = View(this)
        v.layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, 0, weight
        )
        return v
    }

    private fun pill(label: String, bg: String, fg: String, action: String): Button {
        val b = Button(this)
        b.text = label
        b.isAllCaps = false
        b.textSize = 20f
        b.setTextColor(Color.parseColor(fg))
        val shape = GradientDrawable()
        shape.setColor(Color.parseColor(bg))
        shape.cornerRadius = dp(40).toFloat()
        b.background = shape
        b.stateListAnimator = null
        val lp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(64)
        )
        lp.setMargins(dp(40), dp(20), dp(40), 0)
        b.layoutParams = lp
        b.setOnClickListener {
            startService(Intent(this, AlarmService::class.java).setAction(action))
        }
        return b
    }

    override fun onResume() {
        super.onResume()
        handler.post(poll)
    }

    override fun onPause() {
        handler.removeCallbacks(poll)
        super.onPause()
    }
}
