package com.rohitjagtap.pulsekey

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.KeyEvent

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
    private var session: MediaSession? = null
    private var silenceTrack: AudioTrack? = null
    private var silenceThread: Thread? = null

    @Volatile
    private var silenceRunning = false
    private var lastKeyAt = 0L
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
        stopSession()
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
        startSession()
        handler.postDelayed(timeout, MAX_RING_MS)
    }

    private fun finishAlarm(restart: Boolean) {
        handler.removeCallbacks(timeout)
        stopSound()
        stopVibration()
        stopSession()
        abandonFocus()
        if (restart) TimerStore.restart(this) else TimerStore.stop(this)
        EventLog.add(this, if (restart) "alarm: repeat" else "alarm: stopped")
        ringing = false
        stopForeground(true)
        TimerNotifications.cancelAlarmNotification(this)
        stopSelf()
    }

    private fun startSession() {
        try {
            val s = MediaSession(this, "PulseKeyAlarm")
            s.setFlags(
                MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS
            )
            s.setCallback(object : MediaSession.Callback() {
                override fun onMediaButtonEvent(mediaButtonIntent: Intent): Boolean {
                    val ev: KeyEvent? =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            mediaButtonIntent.getParcelableExtra(
                                Intent.EXTRA_KEY_EVENT,
                                KeyEvent::class.java
                            )
                        } else {
                            mediaButtonIntent.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT)
                        }
                    if (ev == null) return true
                    val down = ev.action == KeyEvent.ACTION_DOWN
                    EventLog.add(
                        this@AlarmService,
                        "KEY " + KeyEvent.keyCodeToString(ev.keyCode) +
                            (if (down) " DOWN" else " UP")
                    )
                    if (!down || ev.repeatCount > 0) return true
                    val now = SystemClock.elapsedRealtime()
                    if (now - lastKeyAt < 500L) return true
                    when (ev.keyCode) {
                        KeyEvent.KEYCODE_MEDIA_PLAY,
                        KeyEvent.KEYCODE_MEDIA_PAUSE,
                        KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                        KeyEvent.KEYCODE_HEADSETHOOK -> {
                            lastKeyAt = now
                            finishAlarm(true)
                        }
                        KeyEvent.KEYCODE_MEDIA_NEXT -> {
                            lastKeyAt = now
                            finishAlarm(false)
                        }
                        else -> {}
                    }
                    return true
                }
            })
            val actions = PlaybackState.ACTION_PLAY or
                PlaybackState.ACTION_PAUSE or
                PlaybackState.ACTION_PLAY_PAUSE or
                PlaybackState.ACTION_STOP or
                PlaybackState.ACTION_SKIP_TO_NEXT or
                PlaybackState.ACTION_SKIP_TO_PREVIOUS
            s.setPlaybackState(
                PlaybackState.Builder()
                    .setActions(actions)
                    .setState(PlaybackState.STATE_PLAYING, 0L, 1.0f)
                    .build()
            )
            s.isActive = true
            session = s
            startSilence()
            EventLog.add(this, "neckband control active")
        } catch (e: Exception) {
            EventLog.add(this, "media session failed: " + e.javaClass.simpleName)
        }
    }

    private fun startSilence() {
        try {
            val sampleRate = 8000
            val minBuf = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            val format = AudioFormat.Builder()
                .setSampleRate(sampleRate)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build()
            val t = AudioTrack(
                attrs,
                format,
                minBuf * 2,
                AudioTrack.MODE_STREAM,
                AudioManager.AUDIO_SESSION_ID_GENERATE
            )
            silenceTrack = t
            silenceRunning = true
            val worker = Thread {
                val buf = ShortArray(2048)
                try {
                    t.play()
                    while (silenceRunning) {
                        t.write(buf, 0, buf.size)
                    }
                } catch (e: Exception) {
                    // ignore
                }
            }
            silenceThread = worker
            worker.start()
        } catch (e: Exception) {
            EventLog.add(this, "silent audio failed: " + e.javaClass.simpleName)
        }
    }

    private fun stopSession() {
        silenceRunning = false
        try {
            silenceThread?.join(500)
        } catch (e: InterruptedException) {
            // ignore
        }
        silenceThread = null
        try {
            silenceTrack?.stop()
            silenceTrack?.release()
        } catch (e: Exception) {
            // ignore
        }
        silenceTrack = null
        try {
            session?.isActive = false
            session?.release()
        } catch (e: Exception) {
            // ignore
        }
        session = null
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
