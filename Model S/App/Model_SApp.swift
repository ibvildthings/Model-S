//
//  Model_SApp.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI
import GoogleMaps

@main
struct Model_SApp: App {
    init() {
        // Initialize Google Maps with API key
        // This enables Google Maps visual display
        if let apiKey = MapServiceConfiguration.google.apiKey,
           apiKey != "YOUR_GOOGLE_MAPS_API_KEY" {
            GMSServices.provideAPIKey(apiKey)
            print("✅ Google Maps SDK initialized")
        } else {
            print("⚠️ Google Maps API key not configured - using placeholder")
        }

        // Configure map provider (default is Google Maps)
        // You can change this to .apple if you prefer
        MapProviderManager.shared.useGoogleMaps()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
