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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pulsekey/diag")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        startCapture()
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(Intent(this, DiagService::class.java))
                        result.success(null)
                    }
                    "clear" -> {
                        DiagLog.clear()
                        result.success(null)
                    }
                    "state" -> {
                        result.success(
                            mapOf(
                                "running" to DiagService.running,
                                "log" to DiagLog.snapshot(),
                                "outputs" to audioOutputs()
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startCapture() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 100)
        }
        val intent = Intent(this, DiagService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
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
