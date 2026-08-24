package com.sakuramusic.sakuramusic

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var lyricsOverlayChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "sakuramusic/lyrics_overlay",
        )
        lyricsOverlayChannel = channel
        LyricsOverlayService.setChannel(channel)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> result.success(Settings.canDrawOverlays(this))
                "requestPermission" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                    }
                    result.success(true)
                }
                "show" -> {
                    LyricsOverlayService.start(this)
                    result.success(true)
                }
                "hide" -> {
                    LyricsOverlayService.stop(this)
                    result.success(true)
                }
                "updateLyrics" -> {
                    val current = call.argument<String>("current") ?: ""
                    val next = call.argument<String>("next") ?: ""
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    LyricsOverlayService.updateLyrics(current, next, isPlaying)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        LyricsOverlayService.setChannel(null)
        lyricsOverlayChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
