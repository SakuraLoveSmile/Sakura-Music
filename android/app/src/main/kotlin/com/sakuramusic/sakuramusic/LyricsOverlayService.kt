package com.sakuramusic.sakuramusic

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.text.TextUtils
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.ServiceCompat
import com.sakuramusic.app.R
import io.flutter.plugin.common.MethodChannel

/**
 * Foreground service that renders the floating lyrics window on top of other
 * apps. Flutter drives it through the `sakuramusic/lyrics_overlay` channel
 * registered in [MainActivity]; dragging moves the window, tapping it reopens
 * the app, and the close button reports `onOverlayClosed` back to Dart so the
 * settings switch stays in sync.
 */
class LyricsOverlayService : Service() {

    companion object {
        private const val CHANNEL_ID = "sakuramusic_lyrics_overlay"
        private const val NOTIFICATION_ID = 4101

        @Volatile
        private var instance: LyricsOverlayService? = null

        @Volatile
        private var channel: MethodChannel? = null

        fun setChannel(value: MethodChannel?) {
            channel = value
        }

        fun start(context: Context) {
            val intent = Intent(context, LyricsOverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, LyricsOverlayService::class.java))
        }

        fun updateLyrics(current: String, next: String, isPlaying: Boolean) {
            instance?.renderLyrics(current, next, isPlaying)
        }
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var currentLineView: TextView? = null
    private var nextLineView: TextView? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        startAsForeground()
        showOverlay()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        instance = null
        val view = overlayView
        overlayView = null
        currentLineView = null
        nextLineView = null
        if (view != null) {
            try {
                windowManager?.removeView(view)
            } catch (_: Exception) {
                // The window may already be gone; nothing to clean up then.
            }
        }
        windowManager = null
        super.onDestroy()
    }

    private fun startAsForeground() {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "桌面歌词",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { setShowBadge(false) },
            )
        }
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }
        val notification = builder
            .setSmallIcon(R.drawable.ic_lyrics_overlay)
            .setContentTitle("SakuraMusic")
            .setContentText("桌面歌词运行中")
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .build()
        // The special-use type is declared in the manifest together with the
        // PROPERTY_SPECIAL_USE_FGS_SUBTYPE explanation for Play review.
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            notification,
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
        )
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun showOverlay() {
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        windowManager = wm

        val density = resources.displayMetrics.density
        fun dp(value: Int): Int = (value * density + 0.5f).toInt()

        val currentView = TextView(this).apply {
            text = "♪"
            textSize = 16f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }
        val nextView = TextView(this).apply {
            textSize = 12f
            setTextColor(Color.argb(0x80, 0xFF, 0xFF, 0xFF))
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }
        currentLineView = currentView
        nextLineView = nextView

        val closeButton = TextView(this).apply {
            text = "✕"
            textSize = 13f
            setTextColor(Color.argb(0xB3, 0xFF, 0xFF, 0xFF))
            setPadding(dp(10), 0, dp(2), dp(10))
            setOnClickListener {
                channel?.invokeMethod("onOverlayClosed", null)
                stopSelf()
            }
        }

        val textColumn = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, 0, dp(18), 0)
            addView(currentView)
            addView(nextView)
        }

        val root = FrameLayout(this).apply {
            background = GradientDrawable().apply {
                cornerRadius = dp(18).toFloat()
                setColor(Color.argb(0xB8, 0x10, 0x12, 0x16))
            }
            setPadding(dp(16), dp(10), dp(8), dp(10))
            addView(textColumn)
            addView(
                closeButton,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.TOP or Gravity.END,
                ),
            )
        }
        overlayView = root

        val windowType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            windowType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(16)
            y = dp(120)
        }

        root.setOnTouchListener(OverlayTouchListener(wm, root, params))
        wm.addView(root, params)
    }

    private fun renderLyrics(current: String, next: String, isPlaying: Boolean) {
        currentLineView?.text = if (current.isEmpty()) "♪" else current
        nextLineView?.text = next
        currentLineView?.alpha = if (isPlaying) 1f else 0.6f
    }

    private fun openMainActivity() {
        val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        try {
            startActivity(intent)
        } catch (_: Exception) {
            // The launch intent should always resolve; ignore if it does not.
        }
    }

    /**
     * Distinguishes a drag (window follows the finger) from a tap (reopen the
     * app) using the touch-slop threshold and the press duration.
     */
    private inner class OverlayTouchListener(
        private val manager: WindowManager,
        private val view: View,
        private val params: WindowManager.LayoutParams,
    ) : View.OnTouchListener {
        private var downRawX = 0f
        private var downRawY = 0f
        private var downX = 0f
        private var downY = 0f
        private var downTime = 0L
        private var moved = false

        override fun onTouch(v: View, event: MotionEvent): Boolean {
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downRawX = event.rawX
                    downRawY = event.rawY
                    downX = params.x.toFloat()
                    downY = params.y.toFloat()
                    downTime = System.currentTimeMillis()
                    moved = false
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downRawX
                    val dy = event.rawY - downRawY
                    val slop = ViewConfiguration.get(this@LyricsOverlayService).scaledTouchSlop
                    if (!moved && kotlin.math.abs(dx) <= slop && kotlin.math.abs(dy) <= slop) {
                        return true
                    }
                    moved = true
                    params.x = (downX + dx).toInt()
                    params.y = (downY + dy).toInt()
                    manager.updateViewLayout(view, params)
                    return true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (!moved && System.currentTimeMillis() - downTime < 350) {
                        openMainActivity()
                    }
                    v.performClick()
                    return true
                }
            }
            return false
        }
    }
}
