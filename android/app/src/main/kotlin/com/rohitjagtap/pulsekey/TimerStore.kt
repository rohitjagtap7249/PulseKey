package com.rohitjagtap.pulsekey

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object TimerStore {
    const val IDLE = "idle"
    const val RUNNING = "running"
    const val PAUSED = "paused"
    const val RINGING = "ringing"

    private const val PREFS = "pulsekey_timer"
    private const val K_STATE = "state"
    private const val K_DURATION = "durationMs"
    private const val K_END = "endAtMs"
    private const val K_PAUSED = "pausedRemainingMs"

    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun hms(ms: Long): String =
        SimpleDateFormat("HH:mm:ss", Locale.US).format(Date(ms))

    fun state(ctx: Context): String = prefs(ctx).getString(K_STATE, IDLE) ?: IDLE

    fun durationMs(ctx: Context): Long = prefs(ctx).getLong(K_DURATION, 0L)

    fun remainingMs(ctx: Context): Long {
        val p = prefs(ctx)
        return when (state(ctx)) {
            RUNNING -> maxOf(0L, p.getLong(K_END, 0L) - System.currentTimeMillis())
            PAUSED -> p.getLong(K_PAUSED, 0L)
            else -> 0L
        }
    }

    @Synchronized
    fun start(ctx: Context, durationMs: Long) {
        cancelAlarm(ctx)
        val end = System.currentTimeMillis() + durationMs
        prefs(ctx).edit()
            .putString(K_STATE, RUNNING)
            .putLong(K_DURATION, durationMs)
            .putLong(K_END, end)
            .putLong(K_PAUSED, 0L)
            .commit()
        scheduleAlarm(ctx, end)
        EventLog.add(ctx, "start " + (durationMs / 1000L) + "s, alarm at " + hms(end))
        TimerNotifications.refresh(ctx)
    }

    @Synchronized
    fun pause(ctx: Context) {
        if (state(ctx) != RUNNING) return
        val remaining = remainingMs(ctx)
        cancelAlarm(ctx)
        prefs(ctx).edit()
            .putString(K_STATE, PAUSED)
            .putLong(K_PAUSED, remaining)
            .commit()
        EventLog.add(ctx, "pause, " + (remaining / 1000L) + "s left")
        TimerNotifications.refresh(ctx)
    }

    @Synchronized
    fun resume(ctx: Context) {
        if (state(ctx) != PAUSED) return
        val remaining = maxOf(1000L, prefs(ctx).getLong(K_PAUSED, 0L))
        val end = System.currentTimeMillis() + remaining
        prefs(ctx).edit()
            .putString(K_STATE, RUNNING)
            .putLong(K_END, end)
            .putLong(K_PAUSED, 0L)
            .commit()
        scheduleAlarm(ctx, end)
        EventLog.add(ctx, "resume, alarm at " + hms(end))
        TimerNotifications.refresh(ctx)
    }

    @Synchronized
    fun addTime(ctx: Context, ms: Long) {
        val p = prefs(ctx)
        when (state(ctx)) {
            RUNNING -> {
                val end = p.getLong(K_END, 0L) + ms
                p.edit()
                    .putLong(K_END, end)
                    .putLong(K_DURATION, durationMs(ctx) + ms)
                    .commit()
                scheduleAlarm(ctx, end)
                EventLog.add(ctx, "added " + (ms / 1000L) + "s, alarm at " + hms(end))
                TimerNotifications.refresh(ctx)
            }
            PAUSED -> {
                val rem = p.getLong(K_PAUSED, 0L) + ms
                p.edit()
                    .putLong(K_PAUSED, rem)
                    .putLong(K_DURATION, durationMs(ctx) + ms)
                    .commit()
                EventLog.add(ctx, "added " + (ms / 1000L) + "s while paused")
                TimerNotifications.refresh(ctx)
            }
            else -> {}
        }
    }

    @Synchronized
    fun stop(ctx: Context) {
        cancelAlarm(ctx)
        prefs(ctx).edit()
            .putString(K_STATE, IDLE)
            .putLong(K_PAUSED, 0L)
            .commit()
        EventLog.add(ctx, "stop")
        TimerNotifications.refresh(ctx)
    }

    @Synchronized
    fun restart(ctx: Context) {
        val d = durationMs(ctx)
        if (d > 0L) start(ctx, d)
    }

    @Synchronized
    fun markRinging(ctx: Context) {
        prefs(ctx).edit().putString(K_STATE, RINGING).commit()
        EventLog.add(ctx, "time is up, state set to ringing")
        TimerNotifications.refresh(ctx)
    }

    @Synchronized
    fun rescheduleAfterBoot(ctx: Context) {
        when (state(ctx)) {
            RUNNING -> {
                val end = maxOf(
                    prefs(ctx).getLong(K_END, 0L),
                    System.currentTimeMillis() + 2000L
                )
                scheduleAlarm(ctx, end)
                EventLog.add(ctx, "after reboot, alarm at " + hms(end))
                TimerNotifications.refresh(ctx)
            }
            RINGING -> {
                prefs(ctx).edit().putString(K_STATE, IDLE).commit()
                EventLog.add(ctx, "after reboot, cleared old alarm")
            }
            else -> {}
        }
    }

    private fun piFlags(): Int {
        var f = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            f = f or PendingIntent.FLAG_IMMUTABLE
        }
        return f
    }

    private fun alarmIntent(ctx: Context): PendingIntent {
        val i = Intent(ctx, TimerReceiver::class.java)
            .setAction(TimerReceiver.ACTION_FIRE)
        return PendingIntent.getBroadcast(ctx, 1, i, piFlags())
    }

    private fun scheduleAlarm(ctx: Context, atMs: Long) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val show = PendingIntent.getActivity(
            ctx, 2, Intent(ctx, MainActivity::class.java), piFlags()
        )
        am.setAlarmClock(AlarmManager.AlarmClockInfo(atMs, show), alarmIntent(ctx))
    }

    private fun cancelAlarm(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(alarmIntent(ctx))
    }
}
