//
//  LocationSearchCompleter.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import Foundation
import MapKit
import Combine

/// Handles address autocomplete using MapKit's local search
@MainActor
class LocationSearchCompleter: NSObject, ObservableObject {
    @Published var searchResults: [MKLocalSearchCompletion] = []
    @Published var isSearching = false

    private let searchCompleter = MKLocalSearchCompleter()

    /// Maximum search radius in miles
    private let searchRadiusMiles: Double = 50.0

    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]
    }

    /// Update search region based on user's current location with fixed 50-mile radius
    /// - Parameter userLocation: The user's current coordinate
    func updateSearchRegion(center: CLLocationCoordinate2D) {
        // Convert 50 miles to degrees
        // 1 degree latitude ≈ 69 miles
        let latitudeDelta = (searchRadiusMiles / 69.0) * 2.0 // diameter
        let longitudeDelta = latitudeDelta // simplified, actual varies by latitude

        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: latitudeDelta,
                longitudeDelta: longitudeDelta
            )
        )

        searchCompleter.region = region
    }

    /// Update search query to get suggestions
    func search(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchCompleter.queryFragment = query
    }

    /// Clear search results
    func clearResults() {
        searchResults = []
        isSearching = false
        searchCompleter.queryFragment = ""
    }

    /// Get coordinates for a selected completion
    func getCoordinate(for completion: MKLocalSearchCompletion) async throws -> (CLLocationCoordinate2D, String) {
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
extension LocationSearchCompleter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.searchResults = completer.results
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.searchResults = []
            self.isSearching = false
            print("Search completer error: \(error.localizedDescription)")
        }
    }
}
