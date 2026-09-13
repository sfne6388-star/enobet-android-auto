package com.example.enobet

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val AUTO_CHANNEL = "com.example.enobet/android_auto"
        private const val PREFS_NAME = "enobet_auto"
        private const val NAV_STATE_KEY = "navigation_state"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUTO_CHANNEL,
        ).setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            when (call.method) {
                "updateNavigationState" -> {
                    val json = call.arguments as? String
                    if (json.isNullOrBlank()) {
                        result.error("INVALID_STATE", "Navigation state is empty", null)
                    } else {
                        prefs.edit().putString(NAV_STATE_KEY, json).apply()
                        result.success(null)
                    }
                }

                "clearNavigationState" -> {
                    prefs.edit().remove(NAV_STATE_KEY).apply()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}
