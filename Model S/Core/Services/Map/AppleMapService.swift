//
//  AppleMapService.swift
//  Model S
//
//  Unified Apple Maps service implementing the MapService protocol
//  Composes AppleLocationSearchService, AppleGeocodingService, and AppleRouteCalculationService
//
//  Created by Staff Engineer Refactoring on 11/18/25.
//

import Foundation
import CoreLocation
import Combine

// MARK: - Apple Map Service

/// Unified Apple Maps service that implements all map operations
/// Composes the three separate Apple services into a single, cohesive interface
@MainActor
class AppleMapService: MapService {
    // MARK: - Published Properties

    var searchResults: [LocationSearchResult] {
        searchService.searchResults
    }

    var isSearching: Bool {
        searchService.isSearching
    }

    let provider: MapProvider = .apple

    // MARK: - Private Services

    private let searchService: AppleLocationSearchService
    private let geocodingService: AppleGeocodingService
    private let routeService: AppleRouteCalculationService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        self.searchService = AppleLocationSearchService()
        self.geocodingService = AppleGeocodingService()
        self.routeService = AppleRouteCalculationService()

        // Forward changes from search service
        searchService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    // MARK: - Search Methods

    func search(query: String) {
        searchService.search(query: query)
    }

    func updateSearchRegion(center: CLLocationCoordinate2D, radiusMiles: Double) {
        searchService.updateSearchRegion(center: center, radiusMiles: radiusMiles)
    }

    func clearResults() {
        searchService.clearResults()
    }

    func getCoordinate(for result: LocationSearchResult) async throws -> (CLLocationCoordinate2D, String) {
        do {
            return try await searchService.getCoordinate(for: result)
        } catch {
            throw MapServiceError.geocodingFailed
        }
    }

    // MARK: - Geocoding Methods

    func geocode(address: String) async throws -> (CLLocationCoordinate2D, String) {
        do {
            return try await geocodingService.geocode(address: address)
        } catch {
            throw MapServiceError.geocodingFailed
        }
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String {
        do {
            return try await geocodingService.reverseGeocode(coordinate: coordinate)
        } catch {
            throw MapServiceError.geocodingFailed
        }
    }

    // MARK: - Routing Methods

    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteResult {
        do {
            return try await routeService.calculateRoute(from: from, to: to)
        } catch {
            throw MapServiceError.routeCalculationFailed
        }
    }
}
