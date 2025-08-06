package com.example.hordmaps

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class OverlayManager(private val context: Context) {
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var isOverlayShowing = false
    
    // Notification pour la navigation en arrière-plan
    private var notificationManager: NotificationManager? = null
    private val NAVIGATION_CHANNEL_ID = "hordmaps_navigation"
    private val NAVIGATION_NOTIFICATION_ID = 1001

    init {
        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
    }

    fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    fun showOverlay(instruction: String, distance: Int, duration: Int): Boolean {
        if (!hasOverlayPermission()) {
            return false
        }

        try {
            hideOverlay() // Masquer l'overlay existant s'il y en a un

            // Créer une vue simple pour l'overlay
            overlayView = createOverlayView(instruction, distance, duration)
            
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                },
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT
            )

            params.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            params.y = 100 // Décalage depuis le haut

            windowManager?.addView(overlayView, params)
            isOverlayShowing = true
            return true
            
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    fun hideOverlay() {
        try {
            if (isOverlayShowing && overlayView != null) {
                windowManager?.removeView(overlayView)
                overlayView = null
                isOverlayShowing = false
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun createOverlayView(instruction: String, distance: Int, duration: Int): View {
        // Créer une vue simple avec du texte
        val textView = TextView(context).apply {
            text = buildString {
                append(instruction)
                if (distance > 0) {
                    append("\n")
                    if (distance < 1000) {
                        append("${distance}m")
                    } else {
                        append("${String.format("%.1f", distance / 1000.0)}km")
                    }
                }
                if (duration > 0) {
                    append(" • ${formatDuration(duration)}")
                }
            }
            textSize = 16f
            setTextColor(android.graphics.Color.WHITE)
            setBackgroundColor(android.graphics.Color.parseColor("#CC000000"))
            setPadding(40, 20, 40, 20)
            gravity = Gravity.CENTER
        }
        
        return textView
    }

    private fun formatDuration(seconds: Int): String {
        val minutes = seconds / 60
        return when {
            minutes < 1 -> "${seconds}s"
            minutes < 60 -> "${minutes}min"
            else -> {
                val hours = minutes / 60
                val remainingMinutes = minutes % 60
                "${hours}h ${remainingMinutes}min"
            }
        }
    }

    fun startBackgroundNavigation(destination: String, totalDistance: Double) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        val notification = NotificationCompat.Builder(context, NAVIGATION_CHANNEL_ID)
            .setContentTitle("Navigation HordMaps")
            .setContentText("Navigation vers $destination")
            .setSmallIcon(android.R.drawable.ic_menu_directions)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(NAVIGATION_NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            // Permission de notification non accordée
            e.printStackTrace()
        }
    }

    fun updateNavigationProgress(remainingDistance: Double, eta: String) {
        val distanceText = if (remainingDistance < 1.0) {
            "${(remainingDistance * 1000).toInt()}m restants"
        } else {
            "${String.format("%.1f", remainingDistance)}km restants"
        }

        val notification = NotificationCompat.Builder(context, NAVIGATION_CHANNEL_ID)
            .setContentTitle("Navigation HordMaps")
            .setContentText("$distanceText • Arrivée: $eta")
            .setSmallIcon(android.R.drawable.ic_menu_directions)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(NAVIGATION_NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    fun stopBackgroundNavigation() {
        NotificationManagerCompat.from(context).cancel(NAVIGATION_NOTIFICATION_ID)
        hideOverlay()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NAVIGATION_CHANNEL_ID,
                "Navigation",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications de navigation HordMaps"
                setSound(null, null)
                enableVibration(false)
            }
            
            notificationManager?.createNotificationChannel(channel)
        }
    }
}
