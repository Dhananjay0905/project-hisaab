package app.hisaab.hisaab

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "app.hisaab.hisaab/system"
    }

    override fun onAttachedToEngine(binding: io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding) {
        // Not needed here — channel set up in configureFlutterEngine
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "moveTaskToBack" -> {
                        moveTaskToBack(true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * With singleTask launchMode, Android re-uses the existing Activity
     * and delivers new Intents (deep links, share intents) via onNewIntent
     * instead of onCreate. We must forward them to Flutter here, otherwise
     * they are silently dropped.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}
