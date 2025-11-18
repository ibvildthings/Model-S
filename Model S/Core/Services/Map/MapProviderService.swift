//
//  MapProviderService.swift
//  Model S
//
//  Consolidated map provider service - single source of truth for provider selection and service creation
//  This replaces MapProviderManager and MapProviderPreference with a unified, elegant solution
//
//  Created by Staff Engineer Refactoring on 11/18/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Map Provider Service

/// Single source of truth for map provider management
/// Responsibilities:
/// - Manages current provider selection
/// - Persists user preference
/// - Creates appropriate MapService instances
/// - Validates provider availability (e.g., API keys)
@MainActor
class MapProviderService: ObservableObject {
    // MARK: - Singleton

    static let shared = MapProviderService()

    // MARK: - Published Properties

    /// Current map provider
    @Published private(set) var currentProvider: MapProvider {
        didSet {
            savePreference()
            print("🗺️ Map provider switched to: \(currentProvider.displayName)")
        }
    }

    /// Current map service instance
    @Published private(set) var currentService: AnyMapService

    // MARK: - Computed Properties

    /// Whether Google Maps is available (has valid API key)
    var isGoogleMapsAvailable: Bool {
        guard let apiKey = SecretsManager.googleMapsAPIKey else { return false }
        return apiKey != "YOUR_GOOGLE_MAPS_API_KEY" && !apiKey.isEmpty
    }

    /// Whether Apple Maps is available (always true)
    var isAppleMapsAvailable: Bool {
        true
    }

    /// Available providers based on configuration
    var availableProviders: [MapProvider] {
        MapProvider.allCases.filter { isProviderAvailable($0) }
    }

    // MARK: - Initialization

    private init() {
        // Load saved preference or use default
        let savedProvider = Self.loadSavedProvider()
        self.currentProvider = savedProvider

        // Create initial service
        self.currentService = Self.createService(for: savedProvider)

        print("🗺️ Initialized MapProviderService with \(savedProvider.displayName)")
    }

    // MARK: - Public Methods

    /// Switch to a specific map provider
    /// - Parameter provider: The provider to switch to
    /// - Returns: Result indicating success or failure
    @discardableResult
    func switchTo(provider: MapProvider) -> Result<Void, MapServiceError> {
        // Validate provider availability
        guard isProviderAvailable(provider) else {
            let error = MapServiceError.apiKeyMissing(provider: provider)
            print("⚠️ \(error.localizedDescription)")
            return .failure(error)
        }

        // Switch provider
        currentProvider = provider
        currentService = Self.createService(for: provider)

        return .success(())
    }

    /// Switch to Apple Maps
    @discardableResult
    func useAppleMaps() -> Result<Void, MapServiceError> {
        switchTo(provider: .apple)
    }

    /// Switch to Google Maps
    @discardableResult
    func useGoogleMaps() -> Result<Void, MapServiceError> {
        switchTo(provider: .google)
    }

    /// Toggle between available providers
    func toggleProvider() {
        let nextProvider: MapProvider = currentProvider == .apple ? .google : .apple
        switchTo(provider: nextProvider)
    }

    /// Check if a provider is available
    func isProviderAvailable(_ provider: MapProvider) -> Bool {
        switch provider {
        case .apple:
            return isAppleMapsAvailable
        case .google:
            return isGoogleMapsAvailable
        }
    }

    // MARK: - Private Methods

    /// Load saved provider preference from UserDefaults
    private static func loadSavedProvider() -> MapProvider {
        if let savedProvider = UserDefaults.standard.string(forKey: "selectedMapProvider"),
           let provider = MapProvider(rawValue: savedProvider) {
            return provider
        }
        // Default to Google Maps if available, otherwise Apple Maps
        return SecretsManager.googleMapsAPIKey != nil ? .google : .apple
    }

    /// Save current provider preference to UserDefaults
    private func savePreference() {
        UserDefaults.standard.set(currentProvider.rawValue, forKey: "selectedMapProvider")
    }

    /// Create a map service for the specified provider
    private static func createService(for provider: MapProvider) -> AnyMapService {
        switch provider {
        case .apple:
            return AnyMapService(AppleMapService())
        case .google:
            // Note: GoogleMapService will handle missing API key gracefully
            return AnyMapService(GoogleMapService())
        }
    }
}

// MARK: - SwiftUI Environment Integration

/// Environment key for map provider service
struct MapProviderServiceKey: EnvironmentKey {
    static let defaultValue: MapProviderService = .shared
}

extension EnvironmentValues {
    var mapProviderService: MapProviderService {
        get { self[MapProviderServiceKey.self] }
        set { self[MapProviderServiceKey.self] = newValue }
    }
}

extension View {
    /// Inject map provider service into view hierarchy
    func mapProviderService(_ service: MapProviderService) -> some View {
        environment(\.mapProviderService, service)
    }
}

// MARK: - Map Service Environment

/// Environment key for current map service
struct MapServiceKey: EnvironmentKey {
    @MainActor
    static var defaultValue: AnyMapService {
        MapProviderService.shared.currentService
    }
}

extension EnvironmentValues {
    var mapService: AnyMapService {
        get { self[MapServiceKey.self] }
        set { self[MapServiceKey.self] = newValue }
    }
}

extension View {
    /// Inject map service into view hierarchy
    func mapService(_ service: AnyMapService) -> some View {
        environment(\.mapService, service)
    }
}
