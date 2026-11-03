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
        // Only initialise the Google Maps SDK here. Which provider is *selected*
        // is owned by MapProviderService (it restores the user's saved choice),
        // so the app must not override it on launch.
        #if canImport(GoogleMaps)
        if let apiKey = SecretsManager.googleMapsAPIKey {
            GMSServices.provideAPIKey(apiKey)
            AppLog.map.info("Google Maps SDK initialised")
        } else {
            AppLog.map.info("No Google Maps API key – Apple Maps only (see GOOGLE_MAPS_SETUP.md)")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
