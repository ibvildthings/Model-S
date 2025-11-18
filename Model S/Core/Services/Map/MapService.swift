//
//  MapService.swift
//  Model S
//
//  Unified map service protocol that encapsulates all map-related operations
//  This replaces the fragmented LocationSearchService, GeocodingService, and RouteCalculationService protocols
//
//  Created by Staff Engineer Refactoring on 11/18/25.
//

import Foundation
import CoreLocation
import Combine

// MARK: - Unified Map Service Protocol

/// Comprehensive protocol for all map-related operations
/// Implementations: AppleMapService, GoogleMapService
/// Benefits:
/// - Single interface for all map operations
/// - Easy to add new providers (just implement this protocol)
/// - Simplified dependency injection
/// - Better testability with mock implementations
@MainActor
protocol MapService: ObservableObject {
    // MARK: - Search

    /// Current search results
    var searchResults: [LocationSearchResult] { get }

    /// Whether a search is in progress
    var isSearching: Bool { get }

    /// Search for locations matching the query
    func search(query: String)

    /// Update search region to limit results to nearby area
    func updateSearchRegion(center: CLLocationCoordinate2D, radiusMiles: Double)

    /// Clear current search results
    func clearResults()

    /// Get coordinate for a selected search result
    func getCoordinate(for result: LocationSearchResult) async throws -> (CLLocationCoordinate2D, String)

    // MARK: - Geocoding

    /// Convert address string to coordinate
    func geocode(address: String) async throws -> (CLLocationCoordinate2D, String)

    /// Convert coordinate to address string (reverse geocoding)
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String

    // MARK: - Routing

    /// Calculate route between two points
    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteResult

    // MARK: - Provider Info

    /// The provider this service uses
    var provider: MapProvider { get }
}

// MARK: - Type-Erased Map Service

/// Type-erased wrapper for MapService to work with SwiftUI property wrappers
/// This allows views to use @ObservedObject with any MapService implementation
@MainActor
class AnyMapService: ObservableObject {
    // MARK: - Published Properties

    var searchResults: [LocationSearchResult] {
        _getSearchResults()
    }

    var isSearching: Bool {
        _getIsSearching()
    }

    var provider: MapProvider {
        _getProvider()
    }

    // MARK: - Private Closures

    private let _search: (String) -> Void
    private let _updateSearchRegion: (CLLocationCoordinate2D, Double) -> Void
    private let _clearResults: () -> Void
    private let _getCoordinate: (LocationSearchResult) async throws -> (CLLocationCoordinate2D, String)
    private let _geocode: (String) async throws -> (CLLocationCoordinate2D, String)
    private let _reverseGeocode: (CLLocationCoordinate2D) async throws -> String
    private let _calculateRoute: (CLLocationCoordinate2D, CLLocationCoordinate2D) async throws -> RouteResult
    private let _getSearchResults: () -> [LocationSearchResult]
    private let _getIsSearching: () -> Bool
    private let _getProvider: () -> MapProvider
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init<S: MapService>(_ service: S) {
        self._search = service.search
        self._updateSearchRegion = service.updateSearchRegion
        self._clearResults = service.clearResults
        self._getCoordinate = service.getCoordinate
        self._geocode = service.geocode
        self._reverseGeocode = service.reverseGeocode
        self._calculateRoute = service.calculateRoute
        self._getSearchResults = { service.searchResults }
        self._getIsSearching = { service.isSearching }
        self._getProvider = { service.provider }

        // Forward objectWillChange notifications from the wrapped service
        service.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    // MARK: - Public Methods

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

    func geocode(address: String) async throws -> (CLLocationCoordinate2D, String) {
        try await _geocode(address)
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String {
        try await _reverseGeocode(coordinate)
    }

    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteResult {
        try await _calculateRoute(from, to)
    }
}

// MARK: - Map Service Error

/// Errors that can occur during map service operations
enum MapServiceError: Error, LocalizedError {
    case apiKeyMissing(provider: MapProvider)
    case networkError(underlying: Error)
    case invalidResponse
    case noResultsFound
    case geocodingFailed
    case routeCalculationFailed
    case invalidCoordinate

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing(let provider):
            return "API key missing for \(provider.displayName). Please configure it in Secrets.plist"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from map service"
        case .noResultsFound:
            return "No results found"
        case .geocodingFailed:
            return "Geocoding failed"
        case .routeCalculationFailed:
            return "Route calculation failed"
        case .invalidCoordinate:
            return "Invalid coordinate provided"
        }
    }

    /// Whether this error should fall back to alternate provider
    var shouldFallback: Bool {
        switch self {
        case .apiKeyMissing, .networkError:
            return true
        default:
            return false
        }
    }
}
