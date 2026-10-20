package com.rohitjagtap.pulsekey

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import java.text.DateFormat
import java.util.Date
import java.util.Locale

object TimerNotifications {
    const val CH_TIMER = "pulsekey_timer"
    const val CH_ALARM = "pulsekey_alarm"
    const val CH_FALLBACK = "pulsekey_alarm_fallback"
    const val ID_ALARM = 2
    const val ID_TIMER = 3

    private fun flags(): Int {
        var f = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            f = f or PendingIntent.FLAG_IMMUTABLE
        }
        return f
    }

    private fun nm(ctx: Context): NotificationManager =
        ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun builder(ctx: Context, channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(ctx, channel)
        } else {
            Notification.Builder(ctx)
        }

    private fun ensureChannels(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val m = nm(ctx)

        val timer = NotificationChannel(
            CH_TIMER, "Running timer", NotificationManager.IMPORTANCE_LOW
        )
        timer.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        m.createNotificationChannel(timer)

        val alarm = NotificationChannel(
            CH_ALARM, "Timer finished", NotificationManager.IMPORTANCE_HIGH
        )
        alarm.setSound(null, null)
        alarm.enableVibration(false)
        alarm.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        m.createNotificationChannel(alarm)

        val fb = NotificationChannel(
            CH_FALLBACK, "Timer finished (backup sound)",
            NotificationManager.IMPORTANCE_HIGH
        )
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        fb.setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM), attrs)
        fb.enableVibration(true)
        fb.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        m.createNotificationChannel(fb)
    }

    private fun receiverAction(ctx: Context, code: Int, action: String): PendingIntent {
        val i = Intent(ctx, TimerReceiver::class.java).setAction(action)
        return PendingIntent.getBroadcast(ctx, code, i, flags())
    }

    private fun clock(ms: Long): String {
        val t = (ms + 999L) / 1000L
        val h = t / 3600L
        val m = (t % 3600L) / 60L
        val s = t % 60L
        return String.format(Locale.US, "%02d:%02d:%02d", h, m, s)
    }

    fun refresh(ctx: Context) {
        when (TimerStore.state(ctx)) {
            TimerStore.RUNNING -> showTimer(ctx, true)
            TimerStore.PAUSED -> showTimer(ctx, false)
            else -> nm(ctx).cancel(ID_TIMER)
        }
    }

    private fun showTimer(ctx: Context, running: Boolean) {
        try {
            ensureChannels(ctx)
            val open = PendingIntent.getActivity(
                ctx, 20, Intent(ctx, MainActivity::class.java), flags()
            )
            val remaining = TimerStore.remainingMs(ctx)
            val b = builder(ctx, CH_TIMER)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("Timer")
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(open)
                .setVisibility(Notification.VISIBILITY_PUBLIC)

            if (running) {
                val end = System.currentTimeMillis() + remaining
                b.setWhen(end)
                b.setShowWhen(true)
                b.setUsesChronometer(true)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    b.setChronometerCountDown(true)
                }
                val endText = DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(end))
                b.setContentText("Ends at $endText")
                b.addAction(
                    android.R.drawable.ic_media_pause, "Pause",
                    receiverAction(ctx, 30, TimerReceiver.ACTION_PAUSE)
                )
            } else {
                b.setShowWhen(false)
                b.setContentText("Paused, " + clock(remaining) + " left")
                b.addAction(
                    android.R.drawable.ic_media_play, "Resume",
                    receiverAction(ctx, 31, TimerReceiver.ACTION_RESUME)
                )
            }
            b.addAction(
                android.R.drawable.ic_menu_close_clear_cancel, "Stop",
                receiverAction(ctx, 32, TimerReceiver.ACTION_STOP)
            )
            nm(ctx).notify(ID_TIMER, b.build())
        } catch (e: Exception) {
            EventLog.add(ctx, "timer notification failed: " + e.javaClass.simpleName)
        }
    }

    fun alarmNotification(ctx: Context, channel: String): Notification {
        ensureChannels(ctx)
        val openIntent = Intent(ctx, AlarmActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val open = PendingIntent.getActivity(ctx, 10, openIntent, flags())
        val stop = PendingIntent.getService(
            ctx, 11,
            Intent(ctx, AlarmService::class.java).setAction(AlarmService.ACTION_STOP),
            flags()
        )
        val repeat = PendingIntent.getService(
            ctx, 12,
            Intent(ctx, AlarmService::class.java).setAction(AlarmService.ACTION_REPEAT),
            flags()
        )
        return builder(ctx, channel)
            .setContentTitle("Time's up")
            .setContentText("Timer finished")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setContentIntent(open)
            .setFullScreenIntent(open, true)
            .addAction(android.R.drawable.ic_media_play, "Repeat", repeat)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stop)
            .build()
    }

    fun showFallbackAlarm(ctx: Context) {
        try {
            val n = alarmNotification(ctx, CH_FALLBACK)
            n.flags = n.flags or Notification.FLAG_INSISTENT
            nm(ctx).notify(ID_ALARM, n)
            EventLog.add(ctx, "backup alarm notification posted")
        } catch (e: Exception) {
            EventLog.add(ctx, "backup alarm failed: " + e.javaClass.simpleName)
        }
    }

    fun cancelAlarmNotification(ctx: Context) {
        nm(ctx).cancel(ID_ALARM)
    }
}
