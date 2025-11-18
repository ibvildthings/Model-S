//
//  MapServiceProtocols.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import Foundation
import CoreLocation
import Combine

// MARK: - Map Provider Selection

/// Manages user's map provider preference
@MainActor
class MapProviderPreference: ObservableObject {
    static let shared = MapProviderPreference()

    @Published var selectedProvider: MapProvider {
        didSet {
            // Save to UserDefaults
            let providerString = selectedProvider == .apple ? "apple" : "google"
            UserDefaults.standard.set(providerString, forKey: "selectedMapProvider")
            print("📍 Map provider switched to: \(providerString)")
        }
    }

    private init() {
        // Load saved preference or default to Apple Maps
        if let savedProvider = UserDefaults.standard.string(forKey: "selectedMapProvider") {
            self.selectedProvider = savedProvider == "google" ? .google : .apple
        } else {
            self.selectedProvider = .apple
        }
    }
}

// MARK: - Provider-Agnostic Map Types

/// Provider-agnostic coordinate span (similar to MKCoordinateSpan but with zoom support)
struct MapCoordinateSpan: Equatable, Codable {
    let latitudeDelta: Double
    let longitudeDelta: Double

    /// Google Maps zoom level (0-21), computed from latitude delta
    /// This prevents lossy conversions between span and zoom
    var zoomLevel: Float {
        // Convert latitude delta to zoom level
        // Formula: zoom = log2(360° / latitudeDelta)
        let zoom = log2(360.0 / latitudeDelta)
        return Float(max(0, min(21, zoom)))
    }

    init(latitudeDelta: Double, longitudeDelta: Double) {
        self.latitudeDelta = latitudeDelta
        self.longitudeDelta = longitudeDelta
    }

    /// Create span from Google Maps zoom level
    /// - Parameter zoom: Zoom level (0-21), where 0 = world view, 21 = building view
    init(zoom: Float) {
        let clampedZoom = max(0, min(21, zoom))
        let delta = 360.0 / pow(2.0, Double(clampedZoom))
        self.latitudeDelta = delta
        self.longitudeDelta = delta
    }
}

/// Provider-agnostic map region (replaces MKCoordinateRegion)
/// Works equally well with Apple Maps and Google Maps without conversions
struct MapRegion: Equatable, Codable {
    let center: CLLocationCoordinate2D
    let span: MapCoordinateSpan

    init(center: CLLocationCoordinate2D, span: MapCoordinateSpan) {
        self.center = center
        self.span = span
    }

    /// Convenience initializer matching MKCoordinateRegion API
    init(center: CLLocationCoordinate2D, latitudeDelta: Double, longitudeDelta: Double) {
        self.center = center
        self.span = MapCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
    }

    /// Convenience initializer from zoom level (Google Maps style)
    init(center: CLLocationCoordinate2D, zoom: Float) {
        self.center = center
        self.span = MapCoordinateSpan(zoom: zoom)
    }
}

// MARK: - MKCoordinateRegion Conversion

import MapKit

extension MapRegion {
    /// Convert to MKCoordinateRegion for use with SwiftUI's native Map component
    var toMKCoordinateRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: span.latitudeDelta,
                longitudeDelta: span.longitudeDelta
            )
        )
    }

    /// Create MapRegion from MKCoordinateRegion
    init(mkRegion: MKCoordinateRegion) {
        self.center = mkRegion.center
        self.span = MapCoordinateSpan(
            latitudeDelta: mkRegion.span.latitudeDelta,
            longitudeDelta: mkRegion.span.longitudeDelta
        )
    }
}

/// Provider-agnostic bounding box for map regions
/// Used to calculate regions that fit a set of coordinates
struct MapBounds: Equatable {
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double

    /// Create bounds from a set of coordinates
    init(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else {
            // Default to invalid bounds
            self.minLatitude = 0
            self.maxLatitude = 0
            self.minLongitude = 0
            self.maxLongitude = 0
            return
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        self.minLatitude = minLat
        self.maxLatitude = maxLat
        self.minLongitude = minLon
        self.maxLongitude = maxLon
    }

    /// Center coordinate of the bounds
    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
    }

    /// Convert to MapRegion with padding
    /// - Parameter paddingMultiplier: Multiplier for padding (e.g., 2.0 = ~25% padding on each side)
    func toRegion(paddingMultiplier: Double = 2.0) -> MapRegion {
        let latDelta = (maxLatitude - minLatitude) * paddingMultiplier
        let lonDelta = (maxLongitude - minLongitude) * paddingMultiplier

        return MapRegion(
            center: center,
            span: MapCoordinateSpan(
                latitudeDelta: max(latDelta, 0.01), // Minimum span
                longitudeDelta: max(lonDelta, 0.01)
            )
        )
    }
}

// Make CLLocationCoordinate2D Codable for our needs
extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}

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

/// Type-erased wrapper for LocationSearchService to work with SwiftUI property wrappers
/// This allows views to use @ObservedObject with any LocationSearchService implementation
@MainActor
class AnyLocationSearchService: ObservableObject {
    var searchResults: [LocationSearchResult] {
        _getSearchResults()
    }

    var isSearching: Bool {
        _getIsSearching()
    }

    private let _search: (String) -> Void
    private let _updateSearchRegion: (CLLocationCoordinate2D, Double) -> Void
    private let _clearResults: () -> Void
    private let _getCoordinate: (LocationSearchResult) async throws -> (CLLocationCoordinate2D, String)
    private let _getSearchResults: () -> [LocationSearchResult]
    private let _getIsSearching: () -> Bool
    private var cancellables = Set<AnyCancellable>()

    init<S: LocationSearchService>(_ service: S) {
        self._search = service.search
        self._updateSearchRegion = service.updateSearchRegion
        self._clearResults = service.clearResults
        self._getCoordinate = service.getCoordinate
        self._getSearchResults = { service.searchResults }
        self._getIsSearching = { service.isSearching }

        // Forward objectWillChange notifications from the wrapped service
        service.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    func search(query: String) {
        _search(query)
    }

    func updateSearchRegion(center: CLLocationCoordinate2D, radiusMiles: Double) {
        _updateSearchRegion(center, radiusMiles)
    }

    func clearResults() {
        _clearResults()
    }

    func getCoordinate(for result: LocationSearchResult) async throws -> (CLLocationCoordinate2D, String) {
        try await _getCoordinate(result)
    }
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
/// Provider-agnostic: uses coordinate array instead of provider-specific types
struct RouteResult {
    let distance: Double // meters
    let expectedTravelTime: TimeInterval // seconds
    let coordinates: [CLLocationCoordinate2D] // Provider-agnostic polyline representation

    /// Convenience computed property for backwards compatibility
    /// Returns the coordinate array
    var polyline: [CLLocationCoordinate2D] {
        coordinates
    }
}

/// Protocol for route calculation services
/// Implementations: Apple Maps (MKDirections), Google Directions API
protocol RouteCalculationService {
    /// Calculate route between two points
    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteResult
}

// MARK: - Map Service Provider

/// Enum to specify which map provider to use
enum MapProvider: CaseIterable, Hashable {
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
    /// API key is loaded securely from Secrets.plist (gitignored)
    /// See Secrets.example.plist for setup instructions
    static let google = MapServiceConfiguration(
        provider: .google,
        apiKey: SecretsManager.googleMapsAPIKey
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
    /// Uses the current user preference for map provider
    func createLocationSearchService() -> any LocationSearchService {
        let provider = MapProviderPreference.shared.selectedProvider
        switch provider {
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
    /// Uses the current user preference for map provider
    func createGeocodingService() -> any GeocodingService {
        let provider = MapProviderPreference.shared.selectedProvider
        switch provider {
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
    /// Uses the current user preference for map provider
    func createRouteCalculationService() -> any RouteCalculationService {
        let provider = MapProviderPreference.shared.selectedProvider
        switch provider {
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
