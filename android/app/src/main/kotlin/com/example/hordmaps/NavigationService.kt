package com.example.hordmaps

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class NavigationService : Service() {
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "hordmaps_navigation_service"
    
    private var flutterEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        
        // Initialiser Flutter Engine pour les communications en arrière-plan
        try {
            flutterEngine = FlutterEngine(this)
            flutterEngine?.dartExecutor?.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
            
            methodChannel = MethodChannel(
                flutterEngine!!.dartExecutor.binaryMessenger,
                "com.example.hordmaps/background_navigation"
            )
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START_NAVIGATION" -> {
                val destination = intent.getStringExtra("destination") ?: "Destination"
                val totalDistance = intent.getDoubleExtra("totalDistance", 0.0)
                startForegroundService(destination, totalDistance)
            }
            "UPDATE_NAVIGATION" -> {
                val remainingDistance = intent.getDoubleExtra("remainingDistance", 0.0)
                val eta = intent.getStringExtra("eta") ?: ""
                updateNavigationNotification(remainingDistance, eta)
            }
            "STOP_NAVIGATION" -> {
                stopForeground(true)
                stopSelf()
            }
        }
        
        return START_STICKY
    }

    private fun startForegroundService(destination: String, totalDistance: Double) {
        val notification = createNavigationNotification(
            "Navigation vers $destination",
            "Distance totale: ${formatDistance(totalDistance)}"
        )
        
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun updateNavigationNotification(remainingDistance: Double, eta: String) {
        val distanceText = formatDistance(remainingDistance)
        val notification = createNavigationNotification(
            "Navigation HordMaps",
            "$distanceText restants • Arrivée: $eta"
        )
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun createNavigationNotification(title: String, content: String): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        // Action pour arrêter la navigation
        val stopIntent = Intent(this, NavigationService::class.java).apply {
            action = "STOP_NAVIGATION"
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_menu_directions)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Arrêter",
                stopPendingIntent
            )
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun formatDistance(distanceInKm: Double): String {
        return if (distanceInKm < 1.0) {
            "${(distanceInKm * 1000).toInt()}m"
        } else {
            "${String.format("%.1f", distanceInKm)}km"
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Navigation Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Service de navigation en arrière-plan HordMaps"
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        flutterEngine?.destroy()
        flutterEngine = null
        methodChannel = null
    }
}
