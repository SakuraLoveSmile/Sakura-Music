package com.sakuramusic.sakuramusic

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var lyricsOverlayChannel: MethodChannel? = null
    private var lyriconChannel: MethodChannel? = null

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

        val lyricon = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "sakuramusic/lyricon",
        )
        lyriconChannel = lyricon
        lyricon.setMethodCallHandler { call, result ->
            when (call.method) {
                "register" -> {
                    LyriconBridge.register(this)
                    result.success(true)
                }
                "setSong" -> {
                    val id = call.argument<String>("id") ?: ""
                    val name = call.argument<String>("name") ?: ""
                    val artist = call.argument<String>("artist")
                    val durationMs = call.argument<Number>("durationMs")?.toLong() ?: 0L
                    val rawLines = call.argument<List<Any?>>("lines")
                    val lines = rawLines
                        ?.mapNotNull { it as? Map<String, Any?> }
                        ?: emptyList()
                    LyriconBridge.setSong(id, name, artist, durationMs, lines)
                    result.success(true)
                }
                "setPosition" -> {
                    val ms = call.argument<Number>("ms")?.toLong() ?: 0L
                    LyriconBridge.setPosition(ms)
                    result.success(true)
                }
                "setPlaybackState" -> {
                    val playing = call.argument<Boolean>("playing") ?: false
                    LyriconBridge.setPlaybackState(playing)
                    result.success(true)
                }
                "clearSong" -> {
                    LyriconBridge.clearSong()
                    result.success(true)
                }
                "destroy" -> {
                    LyriconBridge.destroy()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        LyricsOverlayService.setChannel(null)
        lyricsOverlayChannel = null
        // Only unbind the channel reference; the Lyricon provider follows the
        // app process lifetime and must keep running for audio_service.
        lyriconChannel?.setMethodCallHandler(null)
        lyriconChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
