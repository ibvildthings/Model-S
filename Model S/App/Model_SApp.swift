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
           apiKey != "YOUR_GOOGLE_MAPS_API_KEY" && !apiKey.isEmpty {
            GMSServices.provideAPIKey(apiKey)
            print("✅ Google Maps SDK initialized with key: \(String(apiKey.prefix(10)))...")

            // Configure to use Google Maps
            MapProviderManager.shared.useGoogleMaps()
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
