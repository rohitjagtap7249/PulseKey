package com.rohitjagtap.pulsekey

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class TimerReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_FIRE = "com.rohitjagtap.pulsekey.TIMER_FIRE"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_FIRE -> fire(context)
            Intent.ACTION_BOOT_COMPLETED -> TimerStore.rescheduleAfterBoot(context)
        }
    }

    private fun fire(context: Context) {
        if (TimerStore.state(context) != TimerStore.RUNNING) return
        TimerStore.markRinging(context)
        val i = Intent(context, AlarmService::class.java)
            .setAction(AlarmService.ACTION_START)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(i)
        } else {
            context.startService(i)
        }
    }
}
