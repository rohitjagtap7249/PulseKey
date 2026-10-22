package com.rohitjagtap.pulsekey

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class TimerReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_FIRE = "com.rohitjagtap.pulsekey.TIMER_FIRE"
        const val ACTION_PAUSE = "com.rohitjagtap.pulsekey.TIMER_PAUSE"
        const val ACTION_RESUME = "com.rohitjagtap.pulsekey.TIMER_RESUME"
        const val ACTION_STOP = "com.rohitjagtap.pulsekey.TIMER_STOP"
    }

    override fun onReceive(context: Context, intent: Intent) {
        EventLog.add(context, "receiver got " + intent.action)
        when (intent.action) {
            ACTION_FIRE -> fire(context)
            ACTION_PAUSE -> TimerStore.pause(context)
            ACTION_RESUME -> TimerStore.resume(context)
            ACTION_STOP -> TimerStore.stop(context)
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> TimerStore.rescheduleAfterBoot(context)
        }
    }

    private fun fire(context: Context) {
        val st = TimerStore.state(context)
        if (st != TimerStore.RUNNING) {
            EventLog.add(context, "alarm ignored, state was $st")
            return
        }
        TimerStore.markRinging(context)
        try {
            val i = Intent(context, AlarmService::class.java)
                .setAction(AlarmService.ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(i)
            } else {
                context.startService(i)
            }
            EventLog.add(context, "alarm service requested")
        } catch (e: Exception) {
            EventLog.add(context, "alarm service blocked: " + e.javaClass.simpleName)
            TimerNotifications.showFallbackAlarm(context)
        }
    }
}
