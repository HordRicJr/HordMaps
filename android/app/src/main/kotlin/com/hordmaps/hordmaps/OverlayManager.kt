package com.hordmaps.hordmaps

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import android.widget.ProgressBar
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class OverlayManager(private val context: Context) {
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var isOverlayVisible = false

    companion object {
        private const val CHANNEL = "hordmaps/overlay"
    }

    fun initialize(flutterEngine: FlutterEngine) {
        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    result.success(true)
                }
                "showSystemOverlay" -> {
                    val title = call.argument<String>("title") ?: ""
                    val content = call.argument<String>("content") ?: ""
                    val progress = call.argument<Double>("progress") ?: 0.0
                    showSystemOverlay(title, content, progress)
                    result.success(true)
                }
                "hideSystemOverlay" -> {
                    hideSystemOverlay()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun showSystemOverlay(title: String, content: String, progress: Double) {
        if (!canDrawOverlays()) {
            return
        }

        hideSystemOverlay() // Retire l'overlay existant s'il y en a un

        // Créer la vue overlay
        val inflater = LayoutInflater.from(context)
        overlayView = inflater.inflate(R.layout.navigation_overlay, null)

        // Mettre à jour le contenu
        overlayView?.let { view ->
            view.findViewById<TextView>(R.id.overlay_title)?.text = title
            view.findViewById<TextView>(R.id.overlay_content)?.text = content
            view.findViewById<ProgressBar>(R.id.overlay_progress)?.progress = progress.toInt()
        }

        // Configurer les paramètres de la fenêtre
        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.TOP or Gravity.END
        params.x = 50
        params.y = 100

        // Ajouter la vue à la fenêtre
        try {
            windowManager?.addView(overlayView, params)
            isOverlayVisible = true
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun hideSystemOverlay() {
        if (isOverlayVisible && overlayView != null) {
            try {
                windowManager?.removeView(overlayView)
                overlayView = null
                isOverlayVisible = false
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    fun cleanup() {
        hideSystemOverlay()
    }
}
