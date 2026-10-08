package io.github.makiiii_git.y2eknt

import android.content.Intent
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// enableEdgeToEdge() は ComponentActivity の拡張関数のため、
// FlutterActivity ではなく FlutterFragmentActivity（ComponentActivity の子孫）を使う
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "io.github.makiiii_git.y2eknt/share"
    private var sharedText: String? = null
    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 15 未満でもエッジツーエッジ表示にする（Android 15 以降は
        // targetSdk 35+ で強制されるため、全バージョンで見え方をそろえる）。
        // Flutter 側は MediaQuery のパディングでステータスバー・ナビゲーションバーを避ける
        enableEdgeToEdge()
        handleSendIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleSendIntent(intent)
        // アプリ起動中（singleTop）に共有された場合はFlutter側へ即時通知する
        sharedText?.let {
            channel?.invokeMethod("onSharedText", it)
            sharedText = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // コールドスタート時にFlutter側から取得しに来る
                "getSharedText" -> {
                    result.success(sharedText)
                    sharedText = null
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun handleSendIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
        }
    }
}
