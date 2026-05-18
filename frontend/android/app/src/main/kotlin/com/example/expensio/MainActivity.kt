package app.hisaab.hisaab

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
