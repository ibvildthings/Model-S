//
//  MapServiceProtocols.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import Foundation
import CoreLocation

// MARK: - Location Search Service

/// Represents an autocomplete search result
struct LocationSearchResult: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let internalResult: Any // Provider-specific result object

    /// Equatable conformance - compare by ID
    static func == (lhs: LocationSearchResult, rhs: LocationSearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

/// Protocol for location search/autocomplete services
/// Implementations: Apple Maps (MKLocalSearchCompleter), Google Places Autocomplete
@MainActor
protocol LocationSearchService: ObservableObject {
    var searchResults: [LocationSearchResult] { get }
    var isSearching: Bool { get }

    /// Search for locations matching the query
    func search(query: String)

    /// Update search region to limit results to nearby area
    func updateSearchRegion(center: CLLocationCoordinate2D, radiusMiles: Double)

    /// Clear current search results
    func clearResults()

    /// Get coordinate for a selected search result
    func getCoordinate(for result: LocationSearchResult) async throws -> (CLLocationCoordinate2D, String)
}

// MARK: - Geocoding Service

/// Protocol for geocoding services (address ↔ coordinates)
/// Implementations: Apple Maps (CLGeocoder), Google Geocoding API
protocol GeocodingService {
    /// Convert address string to coordinate
    func geocode(address: String) async throws -> (CLLocationCoordinate2D, String)

    /// Convert coordinate to address string (reverse geocoding)
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String
}

// MARK: - Route Calculation Service

/// Represents a calculated route with travel information
struct RouteResult {
    let distance: Double // meters
    let expectedTravelTime: TimeInterval // seconds
    let polyline: Any // Provider-specific polyline object (MKPolyline, GMSPolyline, etc.)
}

/// Protocol for route calculation services
/// Implementations: Apple Maps (MKDirections), Google Directions API
protocol RouteCalculationService {
    /// Calculate route between two points
    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteResult
}

// MARK: - Map Service Provider

/// Enum to specify which map provider to use
enum MapProvider {
    case apple
    case google
}

/// Configuration for map services
struct MapServiceConfiguration {
    let provider: MapProvider
    let apiKey: String? // For Google Maps

    /// Apple Maps configuration (no API key required)
    static let apple = MapServiceConfiguration(provider: .apple, apiKey: nil)

    /// Google Maps configuration with API key
    /// Note: Replace with your actual Google Maps API key
    static let google = MapServiceConfiguration(
        provider: .google,
        apiKey: "YOUR_GOOGLE_MAPS_API_KEY" // Replace with actual API key
    )

    /// Default configuration - now uses Google Maps
    /// Switch to .apple if you prefer Apple Maps
    static let `default` = google
}

// MARK: - Map Service Factory

/// Factory to create map service instances based on provider
@MainActor
class MapServiceFactory {
    static let shared = MapServiceFactory()

    private(set) var configuration: MapServiceConfiguration

    init(configuration: MapServiceConfiguration = .default) {
        self.configuration = configuration
    }

    /// Update the map provider configuration
    func configure(with configuration: MapServiceConfiguration) {
        self.configuration = configuration
    }

    /// Create a location search service instance
    func createLocationSearchService() -> any LocationSearchService {
        switch configuration.provider {
        case .apple:
            return AppleLocationSearchService()
        case .google:
            guard let apiKey = configuration.apiKey else {
                fatalError("Google Maps API key is required. Please configure MapServiceConfiguration with a valid API key.")
            }
            return GoogleLocationSearchService(apiKey: apiKey)
        }
    }

    /// Create a geocoding service instance
    func createGeocodingService() -> any GeocodingService {
        switch configuration.provider {
        case .apple:
            return AppleGeocodingService()
        case .google:
            guard let apiKey = configuration.apiKey else {
                fatalError("Google Maps API key is required. Please configure MapServiceConfiguration with a valid API key.")
            }
            return GoogleGeocodingService(apiKey: apiKey)
        }
    }

    /// Create a route calculation service instance
    func createRouteCalculationService() -> any RouteCalculationService {
        switch configuration.provider {
        case .apple:
            return AppleRouteCalculationService()
        case .google:
            guard let apiKey = configuration.apiKey else {
                fatalError("Google Maps API key is required. Please configure MapServiceConfiguration with a valid API key.")
            }
            return GoogleRouteCalculationService(apiKey: apiKey)
        }
    }
}
