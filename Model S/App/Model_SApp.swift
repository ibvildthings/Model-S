//
//  Model_SApp.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI
#if canImport(GoogleMaps)
import GoogleMaps
#endif

@main
struct Model_SApp: App {
    init() {
        // Initialize Google Maps SDK if available
        #if canImport(GoogleMaps)
        if let apiKey = MapServiceConfiguration.google.apiKey,
           apiKey != "YOUR_GOOGLE_MAPS_API_KEY" && !apiKey.isEmpty && !apiKey.hasPrefix("ghp_") {
            GMSServices.provideAPIKey(apiKey)
            print("✅ Google Maps SDK initialized with key: \(String(apiKey.prefix(10)))...")
            print("📍 Key length: \(apiKey.count) characters")

            // Verify the key format
            if apiKey.hasPrefix("AIza") {
                print("✅ API key format looks correct (starts with AIza)")
            } else {
                print("⚠️ Warning: API key doesn't start with 'AIza' - this might not be a valid Google Maps key")
            }

            // Configure to use Google Maps
            MapProviderManager.shared.useGoogleMaps()
            print("🗺️ Map provider set to: Google Maps")
        } else {
            print("⚠️ Google Maps API key not configured - using Apple Maps")
            print("💡 Add your API key in MapServiceProtocols.swift line 146")
            MapProviderManager.shared.useAppleMaps()
        }
        #else
        print("⚠️ Google Maps SDK not installed - using Apple Maps")
        print("📖 See GOOGLE_MAPS_SETUP.md for installation instructions")
        MapProviderManager.shared.useAppleMaps()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
