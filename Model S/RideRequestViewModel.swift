//
//  RideRequestViewModel.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import Foundation
import MapKit
import Combine

/// Main ViewModel for managing ride request business logic
@MainActor
class RideRequestViewModel: ObservableObject {
    @Published var pickupLocation: LocationPoint?
    @Published var destinationLocation: LocationPoint?
    @Published var pickupAddress: String = ""
    @Published var destinationAddress: String = ""
    @Published var route: MKRoute?
    @Published var rideState: RideRequestState = .selectingPickup
    @Published var error: RideRequestError?
    @Published var isLoading: Bool = false
    @Published var estimatedTravelTime: TimeInterval?
    @Published var estimatedDistance: CLLocationDistance?

    private let geocoder = CLGeocoder()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Geocoding

    /// Convert address string to coordinates
    func geocodeAddress(_ address: String, isPickup: Bool) async {
        guard !address.isEmpty else { return }

        isLoading = true
        error = nil

        do {
            let placemarks = try await geocoder.geocodeAddressString(address)

            guard let placemark = placemarks.first,
                  let location = placemark.location else {
                error = .geocodingFailed
                isLoading = false
                return
            }

            let locationPoint = LocationPoint(
                coordinate: location.coordinate,
                name: formatPlacemark(placemark)
            )

            if isPickup {
                pickupLocation = locationPoint
                pickupAddress = address
            } else {
                destinationLocation = locationPoint
                destinationAddress = address
            }

            // Calculate route if both locations are set
            if pickupLocation != nil && destinationLocation != nil {
                await calculateRoute()
            }

            isLoading = false
        } catch {
            self.error = .geocodingFailed
            isLoading = false
        }
    }

    /// Convert coordinates to address string
    func reverseGeocodeLocation(_ coordinate: CLLocationCoordinate2D, isPickup: Bool) async {
        isLoading = true
        error = nil

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)

            guard let placemark = placemarks.first else {
                error = .geocodingFailed
                isLoading = false
                return
            }

            let address = formatPlacemark(placemark)

            if isPickup {
                pickupAddress = address
                pickupLocation = LocationPoint(coordinate: coordinate, name: address)
            } else {
                destinationAddress = address
                destinationLocation = LocationPoint(coordinate: coordinate, name: address)
            }

            isLoading = false
        } catch {
            self.error = .geocodingFailed
            isLoading = false
        }
    }

    private func formatPlacemark(_ placemark: CLPlacemark) -> String {
        var components: [String] = []

        if let subThoroughfare = placemark.subThoroughfare {
            components.append(subThoroughfare)
        }
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }

        return components.isEmpty ? "Unknown Location" : components.joined(separator: " ")
    }

    // MARK: - Route Calculation

    /// Calculate route using MapKit Directions API
    func calculateRoute() async {
        guard let pickup = pickupLocation,
              let destination = destinationLocation else {
            return
        }

        isLoading = true
        error = nil

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(
            coordinate: pickup.coordinate
        ))
        request.destination = MKMapItem(placemark: MKPlacemark(
            coordinate: destination.coordinate
        ))
        request.transportType = .automobile

        let directions = MKDirections(request: request)

        do {
            let response = try await directions.calculate()

            guard let route = response.routes.first else {
                error = .routeCalculationFailed
                isLoading = false
                return
            }

            self.route = route
            self.estimatedTravelTime = route.expectedTravelTime
            self.estimatedDistance = route.distance
            self.rideState = .routeReady

            isLoading = false
        } catch {
            self.error = .routeCalculationFailed
            isLoading = false
        }
    }

    // MARK: - Validation

    /// Validate that locations are ready for ride request
    func validateLocations() -> Bool {
        guard pickupLocation != nil else {
            error = .invalidPickupLocation
            return false
        }

        guard destinationLocation != nil else {
            error = .invalidDestinationLocation
            return false
        }

        return true
    }

    // MARK: - State Management

    /// Reset to initial state
    func reset() {
        pickupLocation = nil
        destinationLocation = nil
        pickupAddress = ""
        destinationAddress = ""
        route = nil
        rideState = .selectingPickup
        error = nil
        isLoading = false
        estimatedTravelTime = nil
        estimatedDistance = nil
    }

    /// Cancel current ride request
    func cancelRideRequest() {
        if rideState == .rideRequested {
            rideState = .routeReady
        }
    }

    // MARK: - Formatting Helpers

    /// Format travel time for display
    func formattedTravelTime() -> String? {
        guard let time = estimatedTravelTime else { return nil }
        let minutes = Int(time / 60)
        return "\(minutes) min"
    }

    /// Format distance for display
    func formattedDistance() -> String? {
        guard let distance = estimatedDistance else { return nil }
        let miles = distance / 1609.34 // Convert meters to miles
        return String(format: "%.1f mi", miles)
    }
}
