package com.example.hordmaps

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.os.Build
import androidx.annotation.NonNull

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.hordmaps/navigation"
    private lateinit var overlayManager: OverlayManager

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
                "checkOverlayPermission" -> {
                    result.success(overlayManager.hasOverlayPermission())
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
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OVERLAY_PERMISSION_REQUEST_CODE) {
            // Inform Flutter about permission result
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val hasPermission = Settings.canDrawOverlays(this)
                // You could send this back to Flutter via a separate method channel if needed
            }
        }
    }

    companion object {
        private const val OVERLAY_PERMISSION_REQUEST_CODE = 1000
    }
}
