package com.sakuramusic.sakuramusic

import android.content.Context
import android.util.Log
import io.github.proify.lyricon.provider.LyriconFactory
import io.github.proify.lyricon.provider.Provider
import io.github.proify.lyricon.provider.data.RichLyricLine
import io.github.proify.lyricon.provider.data.Song

/**
 * Thin bridge to the Lyricon status-bar lyrics center service.
 *
 * The provider is created lazily and registered once; because the app process
 * is kept alive by audio_service, the provider follows the process lifetime.
 * Every call is wrapped so devices without LSPosed/Lyricon installed degrade
 * silently (the SDK returns an empty implementation / times out on connect).
 */
object LyriconBridge {
    private const val TAG = "LyriconBridge"

    @Volatile
    private var provider: Provider? = null

    @Volatile
    private var registered = false

    /** Bind to the Lyricon center service. Safe to call repeatedly. */
    @Synchronized
    fun register(context: Context) {
        if (registered) return
        try {
            val p = LyriconFactory.createProvider(context.applicationContext)
            p.register()
            provider = p
            registered = true
        } catch (e: Throwable) {
            // Lyricon / LSPosed not installed: nothing to do.
            Log.d(TAG, "Lyricon provider unavailable: ${e.message}")
        }
    }

    /** Push the whole song (title, artist, duration, timed lines) at once. */
    fun setSong(
        id: String,
        name: String,
        artist: String?,
        durationMs: Long,
        lines: List<Map<String, Any?>>,
    ) {
        val p = provider ?: return
        try {
            val lyricLines = ArrayList<RichLyricLine>(lines.size)
            for (line in lines) {
                val begin = (line["begin"] as? Number)?.toLong() ?: 0L
                val end = (line["end"] as? Number)?.toLong() ?: 0L
                val text = line["text"] as? String ?: ""
                lyricLines.add(RichLyricLine(begin, end, text))
            }
            val song = Song.Builder()
                .setId(id)
                .setName(name)
                .setArtist(artist)
                .setDuration(durationMs)
                .setLyrics(lyricLines)
                .build()
            p.setSong(song)
        } catch (e: Throwable) {
            Log.d(TAG, "setSong failed: ${e.message}")
        }
    }

    /** Stream the current playback position in milliseconds. */
    fun setPosition(ms: Long) {
        val p = provider ?: return
        try {
            p.setPosition(ms)
        } catch (e: Throwable) {
            Log.d(TAG, "setPosition failed: ${e.message}")
        }
    }

    /** Stream the play/pause state. */
    fun setPlaybackState(playing: Boolean) {
        val p = provider ?: return
        try {
            p.setPlaybackState(playing)
        } catch (e: Throwable) {
            Log.d(TAG, "setPlaybackState failed: ${e.message}")
        }
    }

    /** Clear the currently displayed song. */
    fun clearSong() {
        val p = provider ?: return
        try {
            p.setSong(null)
        } catch (e: Throwable) {
            Log.d(TAG, "clearSong failed: ${e.message}")
        }
    }

    /** Unbind the provider and release native resources. */
    @Synchronized
    fun destroy() {
        try {
            provider?.unregister()
        } catch (e: Throwable) {
            Log.d(TAG, "unregister failed: ${e.message}")
        }
        provider = null
        registered = false
    }
}
