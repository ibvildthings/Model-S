//
//  MapProviderManager.swift
//  Model S
//
//  Manages map provider configuration with easy switching between Apple Maps and Google Maps
//  Use this manager to change providers at runtime
//
//  Created by Pritesh Desai on 11/17/25.
//

import Foundation
import SwiftUI
import Combine

/// Manager for switching between map providers
@MainActor
class MapProviderManager: ObservableObject {
    static let shared = MapProviderManager()

    /// Current map provider
    @Published var currentProvider: MapProvider {
        didSet {
            updateFactory()
            savePreference()
        }
    }

    /// Whether Google Maps is ready (has valid API key)
    var isGoogleMapsReady: Bool {
        guard let apiKey = MapServiceConfiguration.google.apiKey else { return false }
        return apiKey != "YOUR_GOOGLE_MAPS_API_KEY" && !apiKey.isEmpty
    }

    private init() {
        // Load saved preference or use default
        if let savedProvider = UserDefaults.standard.string(forKey: "selectedMapProvider"),
           let provider = MapProvider(rawValue: savedProvider) {
            self.currentProvider = provider
        } else {
            self.currentProvider = .google // Default to Google Maps
        }

        // Configure factory with saved/default provider
        updateFactory()
    }

    /// Switch to a specific map provider
    func switchTo(provider: MapProvider) {
        currentProvider = provider
    }

    /// Switch to Apple Maps
    func useAppleMaps() {
        switchTo(provider: .apple)
    }

    /// Switch to Google Maps (requires valid API key)
    func useGoogleMaps() {
        guard isGoogleMapsReady else {
            print("⚠️ Google Maps API key not configured. Add your API key in MapServiceConfiguration.google")
            return
        }
        switchTo(provider: .google)
    }

    /// Toggle between Apple and Google Maps
    func toggleProvider() {
        switch currentProvider {
        case .apple:
            useGoogleMaps()
        case .google:
            useAppleMaps()
        }
    }

    // MARK: - Private Methods

    private func updateFactory() {
        let configuration: MapServiceConfiguration
        switch currentProvider {
        case .apple:
            configuration = .apple
        case .google:
            configuration = .google
        }
        MapServiceFactory.shared.configure(with: configuration)
        print("🗺️ Switched to \(currentProvider == .apple ? "Apple Maps" : "Google Maps")")
    }

    private func savePreference() {
        UserDefaults.standard.set(currentProvider.rawValue, forKey: "selectedMapProvider")
    }
}

// MARK: - MapProvider Extension

extension MapProvider: RawRepresentable {
    public init?(rawValue: String) {
        switch rawValue {
        case "apple":
            self = .apple
        case "google":
            self = .google
        default:
            return nil
        }
    }

    public var rawValue: String {
        switch self {
        case .apple:
            return "apple"
        case .google:
            return "google"
        }
    }
}

extension MapProvider {
    var displayName: String {
        switch self {
        case .apple:
            return "Apple Maps"
        case .google:
            return "Google Maps"
        }
    }

    var icon: String {
        switch self {
        case .apple:
            return "map.fill"
        case .google:
            return "globe.americas.fill"
        }
    }
}

// MARK: - SwiftUI Environment

/// Environment key for map provider
struct MapProviderKey: EnvironmentKey {
    static let defaultValue: MapProvider = .google
}

extension EnvironmentValues {
    var mapProvider: MapProvider {
        get { self[MapProviderKey.self] }
        set { self[MapProviderKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Set the map provider for this view hierarchy
    func mapProvider(_ provider: MapProvider) -> some View {
        environment(\.mapProvider, provider)
    }
}
