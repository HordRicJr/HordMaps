package com.example.hordmaps

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel

class LocationService : Service(), LocationListener {
    private val NOTIFICATION_ID = 1002
    private val CHANNEL_ID = "hordmaps_location_service"
    
    private var locationManager: LocationManager? = null
    private var methodChannel: MethodChannel? = null
    private var isTracking = false

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START_LOCATION_TRACKING" -> {
                startLocationTracking()
            }
            "STOP_LOCATION_TRACKING" -> {
                stopLocationTracking()
                stopForeground(true)
                stopSelf()
            }
        }
        
        return START_STICKY
    }

    private fun startLocationTracking() {
        if (isTracking) return
        
        try {
            val notification = createLocationNotification()
            startForeground(NOTIFICATION_ID, notification)
            
            // Demander les mises à jour de localisation
            locationManager?.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                1000, // 1 seconde
                1f,   // 1 mètre
                this
            )
            
            locationManager?.requestLocationUpdates(
                LocationManager.NETWORK_PROVIDER,
                1000,
                1f,
                this
            )
            
            isTracking = true
            
        } catch (e: SecurityException) {
            e.printStackTrace()
            stopSelf()
        }
    }

    private fun stopLocationTracking() {
        if (!isTracking) return
        
        try {
            locationManager?.removeUpdates(this)
            isTracking = false
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onLocationChanged(location: Location) {
        // Envoyer la nouvelle position à Flutter
        methodChannel?.invokeMethod("onLocationUpdate", mapOf(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "accuracy" to location.accuracy,
            "altitude" to location.altitude,
            "bearing" to location.bearing,
            "speed" to location.speed,
            "timestamp" to location.time
        ))
    }

    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {
        // Gérer les changements de statut GPS
    }

    override fun onProviderEnabled(provider: String) {
        // GPS activé
    }

    override fun onProviderDisabled(provider: String) {
        // GPS désactivé
    }

    private fun createLocationNotification(): Notification {
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

        // Action pour arrêter le suivi
        val stopIntent = Intent(this, LocationService::class.java).apply {
            action = "STOP_LOCATION_TRACKING"
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 2, stopIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("HordMaps - Suivi GPS")
            .setContentText("Localisation active en arrière-plan")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Arrêter",
                stopPendingIntent
            )
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Location Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Service de géolocalisation HordMaps"
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
        stopLocationTracking()
    }
}
