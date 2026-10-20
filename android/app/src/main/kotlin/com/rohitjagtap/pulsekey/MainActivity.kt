package com.rohitjagtap.pulsekey

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pulsekey/timer")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val ms = call.argument<Number>("durationMs")?.toLong() ?: 0L
                        if (ms in 60000L..86400000L) {
                            askNotificationPermission()
                            TimerStore.start(this, ms)
                        }
                        result.success(null)
                    }
                    "pause" -> {
                        TimerStore.pause(this)
                        result.success(null)
                    }
                    "resume" -> {
                        TimerStore.resume(this)
                        result.success(null)
                    }
                    "stop" -> {
                        if (TimerStore.state(this) == TimerStore.RINGING) {
                            sendAlarm(AlarmService.ACTION_STOP)
                        } else {
                            TimerStore.stop(this)
                        }
                        result.success(null)
                    }
                    "restart" -> {
                        if (TimerStore.state(this) == TimerStore.RINGING) {
                            sendAlarm(AlarmService.ACTION_REPEAT)
                        } else {
                            TimerStore.restart(this)
                        }
                        result.success(null)
                    }
                    "state" -> {
                        result.success(
                            mapOf(
                                "state" to TimerStore.state(this),
                                "durationMs" to TimerStore.durationMs(this),
                                "remainingMs" to TimerStore.remainingMs(this),
                                "outputs" to audioOutputs()
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun sendAlarm(action: String) {
        startService(Intent(this, AlarmService::class.java).setAction(action))
    }

    private fun askNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 100)
        }
    }

    private fun audioOutputs(): List<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return emptyList()
        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        val list = ArrayList<String>()
        for (d in am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)) {
            val label = when (d.type) {
                AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "Bluetooth A2DP"
                AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "Bluetooth SCO"
                AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "Phone speaker"
                AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "Earpiece"
                else -> "Type ${d.type}"
            }
            list.add("$label: ${d.productName}")
        }
        return list
    }
}
