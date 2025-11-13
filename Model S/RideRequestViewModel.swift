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

    private let geocodingService: any GeocodingService
    private let routeService: any RouteCalculationService
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Create services from factory
        self.geocodingService = MapServiceFactory.shared.createGeocodingService()
        self.routeService = MapServiceFactory.shared.createRouteCalculationService()
    }

    // MARK: - Geocoding

    /// Convert address string to coordinates
    func geocodeAddress(_ address: String, isPickup: Bool) async {
        guard !address.isEmpty else { return }

        isLoading = true
        error = nil

        do {
            let (coordinate, formattedAddress) = try await geocodingService.geocode(address: address)

            let locationPoint = LocationPoint(
                coordinate: coordinate,
                name: formattedAddress
            )

            if isPickup {
                pickupLocation = locationPoint
                pickupAddress = formattedAddress
            } else {
                destinationLocation = locationPoint
                destinationAddress = formattedAddress
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

        do {
            let address = try await geocodingService.reverseGeocode(coordinate: coordinate)

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

    // MARK: - Route Calculation

    /// Calculate route using route service (abstracted)
    func calculateRoute() async {
        guard let pickup = pickupLocation,
              let destination = destinationLocation else {
            return
        }

        isLoading = true
        error = nil

        do {
            let routeResult = try await routeService.calculateRoute(
                from: pickup.coordinate,
                to: destination.coordinate
            )

            // Extract route object (MKRoute for Apple, GMSRoute for Google in future)
            self.route = routeResult.polyline as? MKRoute
            self.estimatedTravelTime = routeResult.expectedTravelTime
            self.estimatedDistance = routeResult.distance
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
