package com.rohitjagtap.pulsekey

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.KeyEvent
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object DiagLog {
    private val lines = ArrayList<String>()
    private val fmt = SimpleDateFormat("HH:mm:ss.SSS", Locale.US)

    @Synchronized
    fun add(msg: String) {
        lines.add(fmt.format(Date()) + "  " + msg)
        if (lines.size > 300) lines.removeAt(0)
    }

    @Synchronized
    fun snapshot(): List<String> = ArrayList(lines)

    @Synchronized
    fun clear() {
        lines.clear()
    }
}

class DiagService : Service() {

    companion object {
        @Volatile
        var running = false
        private const val CHANNEL_ID = "pulsekey_diag"
        private const val NOTIF_ID = 1
    }

    private var session: MediaSession? = null
    private var track: AudioTrack? = null
    private var silenceThread: Thread? = null

    @Volatile
    private var silenceRunning = false
    private val handler = Handler(Looper.getMainLooper())
    private var lastVolume = -1

    private val volumePoll = object : Runnable {
        override fun run() {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val v = am.getStreamVolume(AudioManager.STREAM_MUSIC)
            val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            if (lastVolume == -1) {
                DiagLog.add("Music volume is $v of $max")
            } else if (lastVolume != v) {
                DiagLog.add("VOLUME changed: $lastVolume -> $v (max $max)")
            }
            lastVolume = v
            handler.postDelayed(this, 250)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }

    override fun onCreate() {
        super.onCreate()
        startAsForeground()
        startSession()
        startSilence()
        running = true
        handler.post(volumePoll)
        DiagLog.add("Capture started. PulseKey media session is active.")
    }

    override fun onDestroy() {
        running = false
        handler.removeCallbacks(volumePoll)
        silenceRunning = false
        try {
            silenceThread?.join(500)
        } catch (e: InterruptedException) {
            // ignore
        }
        try {
            track?.stop()
            track?.release()
        } catch (e: Exception) {
            DiagLog.add("AudioTrack release error: ${e.message}")
        }
        track = null
        try {
            session?.isActive = false
            session?.release()
        } catch (e: Exception) {
            DiagLog.add("Session release error: ${e.message}")
        }
        session = null
        DiagLog.add("Capture stopped. Media buttons go back to the previous player.")
        super.onDestroy()
    }

    private fun startAsForeground() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "PulseKey diagnostic",
                    NotificationManager.IMPORTANCE_LOW
                )
            )
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        val notification = builder
            .setContentTitle("PulseKey diagnostic running")
            .setContentText("Capturing media button events")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIF_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIF_ID, notification)
        }
    }

    private fun startSession() {
        val s = MediaSession(this, "PulseKeyDiag")
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
                if (ev == null) {
                    DiagLog.add("Media button intent without KeyEvent")
                    return true
                }
                val action = when (ev.action) {
                    KeyEvent.ACTION_DOWN -> "DOWN"
                    KeyEvent.ACTION_UP -> "UP"
                    else -> "action ${ev.action}"
                }
                DiagLog.add(
                    "KEY ${KeyEvent.keyCodeToString(ev.keyCode)} (${ev.keyCode}) " +
                        "$action repeat=${ev.repeatCount}"
                )
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
            track = t
            silenceRunning = true
            val worker = Thread {
                val buf = ShortArray(2048)
                try {
                    t.play()
                    while (silenceRunning) {
                        t.write(buf, 0, buf.size)
                    }
                } catch (e: Exception) {
                    DiagLog.add("Silence thread error: ${e.message}")
                }
            }
            silenceThread = worker
            worker.start()
            DiagLog.add("Silent audio started (no audio focus requested).")
        } catch (e: Exception) {
            DiagLog.add("Could not start silent audio: ${e.message}")
        }
    }
}
