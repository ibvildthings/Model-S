//
//  GoogleMapService.swift
//  Model S
//
//  Unified Google Maps service implementing the MapService protocol
//  Composes GoogleLocationSearchService, GoogleGeocodingService, and GoogleRouteCalculationService
//
//  Created by Staff Engineer Refactoring on 11/18/25.
//

import Foundation
import CoreLocation
import Combine

// MARK: - Google Map Service

/// Unified Google Maps service that implements all map operations
/// Composes the three separate Google services into a single, cohesive interface
@MainActor
class GoogleMapService: MapService {
    // MARK: - Published Properties

    var searchResults: [LocationSearchResult] {
        searchService.searchResults
    }

    var isSearching: Bool {
        searchService.isSearching
    }

    let provider: MapProvider = .google

    // MARK: - Private Services

    private let searchService: GoogleLocationSearchService
    private let geocodingService: GoogleGeocodingService
    private let routeService: GoogleRouteCalculationService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Get API key from secrets manager
        // Note: Services will handle missing API key gracefully by throwing MapServiceError
        let apiKey = SecretsManager.googleMapsAPIKey ?? ""

        self.searchService = GoogleLocationSearchService(apiKey: apiKey)
        self.geocodingService = GoogleGeocodingService(apiKey: apiKey)
        self.routeService = GoogleRouteCalculationService(apiKey: apiKey)

        // Forward changes from search service
        searchService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    /// Initialize with explicit API key (useful for testing)
    init(apiKey: String) {
        self.searchService = GoogleLocationSearchService(apiKey: apiKey)
        self.geocodingService = GoogleGeocodingService(apiKey: apiKey)
        self.routeService = GoogleRouteCalculationService(apiKey: apiKey)

        // Forward changes from search service
        searchService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    // MARK: - Search Methods

    func search(query: String) {
        // Check for API key before searching
        guard SecretsManager.googleMapsAPIKey != nil else {
            print("⚠️ \(MapServiceError.apiKeyMissing(provider: .google).localizedDescription)")
            return
        }
        searchService.search(query: query)
    }

    func updateSearchRegion(center: CLLocationCoordinate2D, radiusMiles: Double) {
        searchService.updateSearchRegion(center: center, radiusMiles: radiusMiles)
    }

    func clearResults() {
        searchService.clearResults()
    }

    func getCoordinate(for result: LocationSearchResult) async throws -> (CLLocationCoordinate2D, String) {
        guard SecretsManager.googleMapsAPIKey != nil else {
            throw MapServiceError.apiKeyMissing(provider: .google)
        }

        do {
            return try await searchService.getCoordinate(for: result)
        } catch {
            throw MapServiceError.geocodingFailed
        }
    }

    // MARK: - Geocoding Methods

    func geocode(address: String) async throws -> (CLLocationCoordinate2D, String) {
        guard SecretsManager.googleMapsAPIKey != nil else {
            throw MapServiceError.apiKeyMissing(provider: .google)
        }

        do {
            return try await geocodingService.geocode(address: address)
        } catch {
            throw MapServiceError.geocodingFailed
        }
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String {
        guard SecretsManager.googleMapsAPIKey != nil else {
            throw MapServiceError.apiKeyMissing(provider: .google)
        }

        do {
            return try await geocodingService.reverseGeocode(coordinate: coordinate)
        } catch {
            throw MapServiceError.geocodingFailed
        }
    }

    // MARK: - Routing Methods

    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteResult {
        guard SecretsManager.googleMapsAPIKey != nil else {
            throw MapServiceError.apiKeyMissing(provider: .google)
        }

        do {
            return try await routeService.calculateRoute(from: from, to: to)
        } catch {
            throw MapServiceError.routeCalculationFailed
        }
    }
}
