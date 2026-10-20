package com.rohitjagtap.pulsekey

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

class AlarmService : Service() {

    companion object {
        const val ACTION_START = "com.rohitjagtap.pulsekey.ALARM_START"
        const val ACTION_STOP = "com.rohitjagtap.pulsekey.ALARM_STOP"
        const val ACTION_REPEAT = "com.rohitjagtap.pulsekey.ALARM_REPEAT"
        private const val MAX_RING_MS = 5 * 60 * 1000L
    }

    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var focusRequest: AudioFocusRequest? = null
    private var ringing = false
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { finishAlarm(false) }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> finishAlarm(false)
            ACTION_REPEAT -> finishAlarm(true)
            else -> startRinging()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(timeout)
        stopSound()
        stopVibration()
        super.onDestroy()
    }

    private fun startRinging() {
        if (ringing) return
        ringing = true
        EventLog.add(this, "alarm service running")
        try {
            val n = TimerNotifications.alarmNotification(this, TimerNotifications.CH_ALARM)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    TimerNotifications.ID_ALARM,
                    n,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                )
            } else {
                startForeground(TimerNotifications.ID_ALARM, n)
            }
        } catch (e: Exception) {
            EventLog.add(this, "startForeground failed: " + e.javaClass.simpleName)
            TimerNotifications.showFallbackAlarm(this)
            ringing = false
            stopSelf()
            return
        }
        requestFocus()
        startSound()
        startVibration()
        handler.postDelayed(timeout, MAX_RING_MS)
    }

    private fun finishAlarm(restart: Boolean) {
        handler.removeCallbacks(timeout)
        stopSound()
        stopVibration()
        abandonFocus()
        if (restart) TimerStore.restart(this) else TimerStore.stop(this)
        EventLog.add(this, if (restart) "alarm: repeat" else "alarm: stopped")
        ringing = false
        stopForeground(true)
        TimerNotifications.cancelAlarmNotification(this)
        stopSelf()
    }

    private fun requestFocus() {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                .build()
            focusRequest = req
            am.requestAudioFocus(req)
        } else {
            am.requestAudioFocus(
                null,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
            )
        }
    }

    private fun abandonFocus() {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { am.abandonAudioFocusRequest(it) }
            focusRequest = null
        } else {
            am.abandonAudioFocus(null)
        }
    }

    private fun startSound() {
        try {
            var uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            if (uri == null) {
                uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            }
            val mp = MediaPlayer()
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            mp.setDataSource(this, uri)
            mp.isLooping = true
            mp.prepare()
            mp.start()
            player = mp
            EventLog.add(this, "ringtone playing")
        } catch (e: Exception) {
            player = null
            EventLog.add(this, "ringtone failed: " + e.javaClass.simpleName)
        }
    }

    private fun stopSound() {
        try {
            player?.stop()
            player?.release()
        } catch (e: Exception) {
            // ignore
        }
        player = null
    }

    private fun startVibration() {
        try {
            val v: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager)
                    .defaultVibrator
            } else {
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            vibrator = v
            val pattern = longArrayOf(0, 600, 400)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                v.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                v.vibrate(pattern, 0)
            }
        } catch (e: Exception) {
            EventLog.add(this, "vibration failed: " + e.javaClass.simpleName)
        }
    }

    private fun stopVibration() {
        vibrator?.cancel()
        vibrator = null
    }
}
