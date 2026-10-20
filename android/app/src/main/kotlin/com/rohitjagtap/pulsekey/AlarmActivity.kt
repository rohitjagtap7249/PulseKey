package com.rohitjagtap.pulsekey

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
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

        val d = resources.displayMetrics.density
        val pad = (24 * d).toInt()

        val root = LinearLayout(this)
        root.orientation = LinearLayout.VERTICAL
        root.gravity = Gravity.CENTER
        root.setBackgroundColor(Color.parseColor("#101414"))
        root.setPadding(pad, pad, pad, pad)

        val title = TextView(this)
        title.text = "Timer finished"
        title.textSize = 32f
        title.setTextColor(Color.WHITE)
        title.gravity = Gravity.CENTER
        root.addView(title)

        val minutes = TimerStore.durationMs(this) / 60000L
        val sub = TextView(this)
        sub.text = "$minutes min timer"
        sub.textSize = 16f
        sub.setTextColor(Color.LTGRAY)
        sub.gravity = Gravity.CENTER
        root.addView(sub)

        addButton(root, "Repeat timer", AlarmService.ACTION_REPEAT, d)
        addButton(root, "Stop", AlarmService.ACTION_STOP, d)

        setContentView(root)
    }

    private fun addButton(root: LinearLayout, label: String, action: String, d: Float) {
        val b = Button(this)
        b.text = label
        val lp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        lp.topMargin = (20 * d).toInt()
        b.layoutParams = lp
        b.setOnClickListener {
            startService(Intent(this, AlarmService::class.java).setAction(action))
        }
        root.addView(b)
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
