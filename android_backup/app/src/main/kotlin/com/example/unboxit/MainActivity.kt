package com.example.unboxit

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register the ListTileNativeAdFactory
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine, "listTile",
            NativeAdFactory(context)
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        
        // Unregister the ListTileNativeAdFactory
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "listTile")
    }
}
