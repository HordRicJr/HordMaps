package com.example.hordmaps

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.os.Build
import android.app.AppOpsManager
import android.content.pm.PackageManager
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.hordmaps/navigation"
    private lateinit var overlayManager: OverlayManager
    private val OVERLAY_PERMISSION_REQUEST_CODE = 1000
    private val PERMISSIONS_REQUEST_CODE = 1001

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        overlayManager = OverlayManager(this)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showNavigationOverlay" -> {
                    val instruction = call.argument<String>("instruction") ?: ""
                    val distance = call.argument<Int>("distance") ?: 0
                    val duration = call.argument<Int>("duration") ?: 0
                    
                    if (overlayManager.showOverlay(instruction, distance, duration)) {
                        result.success(true)
                    } else {
                        result.error("PERMISSION_DENIED", "Overlay permission not granted", null)
                    }
                }
                "hideNavigationOverlay" -> {
                    overlayManager.hideOverlay()
                    result.success(true)
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(true)
                }
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(true)
                }
                "checkOverlayPermission" -> {
                    result.success(hasOverlayPermission())
                }
                "requestAllPermissions" -> {
                    requestAllNecessaryPermissions()
                    result.success(true)
                }
                "checkAllPermissions" -> {
                    result.success(hasAllNecessaryPermissions())
                }
                "startBackgroundNavigation" -> {
                    val destination = call.argument<String>("destination") ?: ""
                    val totalDistance = call.argument<Double>("totalDistance") ?: 0.0
                    
                    overlayManager.startBackgroundNavigation(destination, totalDistance)
                    result.success(true)
                }
                "stopBackgroundNavigation" -> {
                    overlayManager.stopBackgroundNavigation()
                    result.success(true)
                }
                "updateNavigationProgress" -> {
                    val remainingDistance = call.argument<Double>("remainingDistance") ?: 0.0
                    val eta = call.argument<String>("eta") ?: ""
                    
                    overlayManager.updateNavigationProgress(remainingDistance, eta)
                    result.success(true)
                }
                "startLocationService" -> {
                    val intent = Intent(this, LocationService::class.java).apply {
                        action = "START_LOCATION_TRACKING"
                    }
                    startForegroundService(intent)
                    result.success(true)
                }
                "stopLocationService" -> {
                    val intent = Intent(this, LocationService::class.java).apply {
                        action = "STOP_LOCATION_TRACKING"
                    }
                    startService(intent)
                    result.success(true)
                }
                "startNavigationService" -> {
                    val destination = call.argument<String>("destination") ?: ""
                    val totalDistance = call.argument<Double>("totalDistance") ?: 0.0
                    
                    val intent = Intent(this, NavigationService::class.java).apply {
                        action = "START_NAVIGATION"
                        putExtra("destination", destination)
                        putExtra("totalDistance", totalDistance)
                    }
                    startForegroundService(intent)
                    result.success(true)
                }
                "stopNavigationService" -> {
                    val intent = Intent(this, NavigationService::class.java).apply {
                        action = "STOP_NAVIGATION"
                    }
                    startService(intent)
                    result.success(true)
                }
                "updateNavigationService" -> {
                    val remainingDistance = call.argument<Double>("remainingDistance") ?: 0.0
                    val eta = call.argument<String>("eta") ?: ""
                    
                    val intent = Intent(this, NavigationService::class.java).apply {
                        action = "UPDATE_NAVIGATION"
                        putExtra("remainingDistance", remainingDistance)
                        putExtra("eta", eta)
                    }
                    startService(intent)
                    result.success(true)
                }
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(true)
                }
                "forceOverlayPermission" -> {
                    forceOverlayPermission()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun hasAllNecessaryPermissions(): Boolean {
        val permissions = listOf(
            android.Manifest.permission.ACCESS_FINE_LOCATION,
            android.Manifest.permission.ACCESS_COARSE_LOCATION,
            android.Manifest.permission.POST_NOTIFICATIONS
        )
        
        return permissions.all { permission ->
            ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
        } && hasOverlayPermission()
    }

    private fun requestAllNecessaryPermissions() {
        val permissions = mutableListOf<String>()
        
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            permissions.add(android.Manifest.permission.ACCESS_FINE_LOCATION)
        }
        
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            permissions.add(android.Manifest.permission.ACCESS_COARSE_LOCATION)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                permissions.add(android.Manifest.permission.POST_NOTIFICATIONS)
            }
        }
        
        if (permissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissions.toTypedArray(), PERMISSIONS_REQUEST_CODE)
        }
        
        // Demander la permission d'overlay séparément
        if (!hasOverlayPermission()) {
            requestOverlayPermission()
        }
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                // Pour Android 15, utiliser une approche plus directe
                val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
                    // Android 15+ - nouvelle approche
                    Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                        data = Uri.parse("package:$packageName")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                } else {
                    // Android 6-14
                    Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                }
                
                try {
                    startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
                } catch (e: Exception) {
                    // Fallback: ouvrir les paramètres généraux de l'app
                    val fallbackIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:$packageName")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(fallbackIntent)
                }
            }
        }
    }

    private fun openOverlaySettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } catch (e: Exception) {
                // Fallback: ouvrir les paramètres de l'application
                val fallbackIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(fallbackIntent)
            }
        }
    }

    private fun forceOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                // Essayer d'ouvrir directement les paramètres de superposition
                val intent1 = Intent("android.settings.action.MANAGE_OVERLAY_PERMISSION").apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent1)
            } catch (e1: Exception) {
                try {
                    // Fallback 1: Paramètres système overlay
                    val intent2 = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent2)
                } catch (e2: Exception) {
                    try {
                        // Fallback 2: Paramètres application spécifiques
                        val intent3 = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent3)
                    } catch (e3: Exception) {
                        // Fallback 3: Paramètres généraux
                        val intent4 = Intent(Settings.ACTION_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent4)
                    }
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            OVERLAY_PERMISSION_REQUEST_CODE -> {
                // Informer Flutter du résultat
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val hasPermission = Settings.canDrawOverlays(this)
                    // Vous pourriez envoyer cela via un MethodChannel si nécessaire
                }
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            PERMISSIONS_REQUEST_CODE -> {
                // Traiter les résultats des permissions
                val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                // Vous pourriez informer Flutter du résultat
            }
        }
    }

    companion object {
        private const val OVERLAY_PERMISSION_REQUEST_CODE = 1000
        private const val PERMISSIONS_REQUEST_CODE = 1001
    }
}
