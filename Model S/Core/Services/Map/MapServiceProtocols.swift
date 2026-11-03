//
//  MapServiceProtocols.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import Foundation
import CoreLocation
import Combine

// MARK: - Provider-Agnostic Map Types

/// Provider-agnostic coordinate span (similar to MKCoordinateSpan but with zoom support)
struct MapCoordinateSpan: Equatable, Codable {
    let latitudeDelta: Double
    let longitudeDelta: Double

    /// Google Maps zoom level (0-21), computed from coordinate deltas
    /// Uses the most constrained dimension to ensure both fit in view
    var zoomLevel: Float {
        // Convert deltas to zoom levels
        // Formula: zoom = log2(360° / delta)
        let latZoom = log2(360.0 / latitudeDelta)
        let lonZoom = log2(360.0 / longitudeDelta)

        // Use the smaller zoom (most constrained dimension)
        // This ensures both the latitude and longitude extents fit in the view
        let zoom = min(latZoom, lonZoom)
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

// MARK: - Map Provider

/// Which map SDK / web APIs back the map, search, geocoding and routing.
/// The current selection is owned by `MapProviderService`.
enum MapProvider: String, CaseIterable, Hashable {
    case apple
    case google

    var displayName: String {
        switch self {
        case .apple: return "Apple Maps"
        case .google: return "Google Maps"
        }
    }

    /// SF Symbol name used in provider pickers
    var icon: String {
        switch self {
        case .apple: return "map.fill"
        case .google: return "globe.americas.fill"
        }
    }
}
