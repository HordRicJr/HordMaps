package com.hordmaps.hordmaps

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    private lateinit var overlayManager: OverlayManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialiser l'OverlayManager
        overlayManager = OverlayManager(this)
        overlayManager.initialize(flutterEngine)
        
        // Demander la permission d'overlay au démarrage si nécessaire
        checkOverlayPermission()
    }

    private fun checkOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            // Ouvrir les paramètres pour permettre l'overlay
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::overlayManager.isInitialized) {
            overlayManager.cleanup()
        }
    }
}
