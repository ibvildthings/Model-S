//
//  AppleMapServices.swift
//  Model S
//
//  Apple Maps implementations of map service protocols.
//  Provides location search, geocoding, and route calculation using MapKit.
//
//  Created by Pritesh Desai on 11/12/25.
//

import Foundation
import MapKit
import Combine

// MARK: - Apple Location Search Service

/// Apple Maps implementation of location autocomplete using MKLocalSearchCompleter
/// Provides real-time search suggestions as user types
@MainActor
class AppleLocationSearchService: NSObject, LocationSearchService, ObservableObject {
    /// Current search results (updated as user types)
    @Published var searchResults: [LocationSearchResult] = []

    /// Whether a search is currently in progress
    @Published var isSearching = false

    /// MKLocalSearchCompleter handles the actual autocomplete
    private let searchCompleter = MKLocalSearchCompleter()

    /// Current search region (limits results to nearby area)
    private var currentRegion: MKCoordinateRegion?

    override init() {
        super.init()
        searchCompleter.delegate = self
        // Search for both addresses and points of interest
        searchCompleter.resultTypes = [.address, .pointOfInterest]
    }

    /// Searches for locations matching the query string
    /// - Parameter query: The search text (e.g., "123 Main St" or "Starbucks")
    func search(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchCompleter.queryFragment = query
    }

    /// Limits search results to a region around the given center point
    /// - Parameters:
    ///   - center: The center coordinate
    ///   - radiusMiles: Radius in miles to search within
    func updateSearchRegion(center: CLLocationCoordinate2D, radiusMiles: Double) {
        // Convert radius from miles to coordinate degrees
        let latitudeDelta = (radiusMiles / MapConstants.milesPerDegree) * 2.0
        let longitudeDelta = latitudeDelta

        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: latitudeDelta,
                longitudeDelta: longitudeDelta
            )
        )

        currentRegion = region
        searchCompleter.region = region
    }

    func clearResults() {
        searchResults = []
        isSearching = false
        searchCompleter.queryFragment = ""
    }

    func getCoordinate(for result: LocationSearchResult) async throws -> (CLLocationCoordinate2D, String) {
        guard let completion = result.internalResult as? MKLocalSearchCompletion else {
            throw RideRequestError.geocodingFailed
        }

        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)

        let response = try await search.start()

        guard let mapItem = response.mapItems.first else {
            throw RideRequestError.geocodingFailed
        }

        let coordinate = mapItem.placemark.coordinate
        let name = mapItem.name ?? completion.title

        return (coordinate, name)
    }
}

// MARK: - MKLocalSearchCompleterDelegate
extension AppleLocationSearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.searchResults = completer.results.map { completion in
                LocationSearchResult(
                    title: completion.title,
                    subtitle: completion.subtitle,
                    internalResult: completion
                )
            }
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.searchResults = []
            self.isSearching = false
            print("Apple search completer error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Apple Geocoding Service

/// Apple Maps implementation of GeocodingService using CLGeocoder
class AppleGeocodingService: GeocodingService {
    private let geocoder = CLGeocoder()

    func geocode(address: String) async throws -> (CLLocationCoordinate2D, String) {
        let placemarks = try await geocoder.geocodeAddressString(address)

        guard let placemark = placemarks.first,
              let location = placemark.location else {
            throw RideRequestError.geocodingFailed
        }

        // Build formatted address
        var addressComponents: [String] = []
        if let name = placemark.name { addressComponents.append(name) }
        if let locality = placemark.locality { addressComponents.append(locality) }
        if let state = placemark.administrativeArea { addressComponents.append(state) }

        let formattedAddress = addressComponents.isEmpty ? address : addressComponents.joined(separator: ", ")

        return (location.coordinate, formattedAddress)
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try await geocoder.reverseGeocodeLocation(location)

        guard let placemark = placemarks.first else {
            throw RideRequestError.geocodingFailed
        }

        // Build formatted address
        var addressComponents: [String] = []
        if let name = placemark.name { addressComponents.append(name) }
        if let locality = placemark.locality { addressComponents.append(locality) }
        if let state = placemark.administrativeArea { addressComponents.append(state) }

        return addressComponents.isEmpty ? "Unknown Location" : addressComponents.joined(separator: ", ")
    }
}

// MARK: - Apple Route Calculation Service

/// Apple Maps implementation of RouteCalculationService using MKDirections
class AppleRouteCalculationService: RouteCalculationService {
    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteResult {
        let sourcePlacemark = MKPlacemark(coordinate: from)
        let destinationPlacemark = MKPlacemark(coordinate: to)

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw RideRequestError.routeCalculationFailed
        }

        return RouteResult(
            distance: route.distance,
            expectedTravelTime: route.expectedTravelTime,
            polyline: route // Store full MKRoute for Apple implementation
        )
    }
}
