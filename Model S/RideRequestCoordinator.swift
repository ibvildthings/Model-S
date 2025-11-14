//
//  RideRequestCoordinator.swift
//  Model S
//
//  Coordinator that orchestrates ride request business logic.
//  Simplifies views by centralizing all complex state management and service coordination.
//
//  Created by Pritesh Desai on 11/13/25.
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation

/// Coordinates the entire ride request flow
/// Manages ViewModels, services, and complex business logic so views can stay simple
@MainActor
class RideRequestCoordinator: ObservableObject {
    // MARK: - Published State

    /// Main ride request state (published for view observation)
    @Published private(set) var viewModel: RideRequestViewModel

    /// Map display state (published for view observation)
    @Published private(set) var mapViewModel: MapViewModel

    /// Whether the confirm slider should be visible
    @Published var showConfirmSlider = false

    // MARK: - Private Dependencies

    private let configuration: RideRequestConfiguration
    private let geocodingDebouncer: Debouncer

    // MARK: - Initialization

    /// Creates a coordinator with the given configuration
    /// - Parameter configuration: UI and feature configuration
    init(configuration: RideRequestConfiguration = .default) {
        self.configuration = configuration
        self.viewModel = RideRequestViewModel()
        self.mapViewModel = MapViewModel()
        self.geocodingDebouncer = Debouncer(delay: TimingConstants.geocodingDebounceDelay)

        setupLocationUpdates()
    }

    // MARK: - Location Selection

    /// Handles when user selects a location from autocomplete or map
    /// - Parameters:
    ///   - coordinate: The selected coordinate
    ///   - name: The location name/address
    ///   - isPickup: Whether this is pickup (true) or destination (false)
    func selectLocation(coordinate: CLLocationCoordinate2D, name: String, isPickup: Bool) async {
        // Cancel any pending geocoding since we have exact coordinates
        geocodingDebouncer.cancel()

        // Create location point
        let locationPoint = LocationPoint(coordinate: coordinate, name: name)

        // Update ride request state
        if isPickup {
            viewModel.pickupLocation = locationPoint
            viewModel.pickupAddress = name
            mapViewModel.updatePickupLocation(coordinate, name: name)
        } else {
            viewModel.destinationLocation = locationPoint
            viewModel.destinationAddress = name
            mapViewModel.updateDestinationLocation(coordinate, name: name)
        }

        // Auto-calculate route if both locations are set
        if configuration.enableRouteCalculation {
            await calculateRouteIfReady()
        }

        // Update UI state
        updateConfirmSliderVisibility()
    }

    /// Handles when user types in address field (debounced geocoding)
    /// - Parameters:
    ///   - address: The address text
    ///   - isPickup: Whether this is pickup (true) or destination (false)
    func addressTextChanged(_ address: String, isPickup: Bool) {
        guard configuration.enableGeocoding else { return }
        guard !address.isEmpty else {
            // Clear location if text is empty
            if isPickup {
                viewModel.pickupLocation = nil
                mapViewModel.pickupLocation = nil
            } else {
                viewModel.destinationLocation = nil
                mapViewModel.destinationLocation = nil
            }
            updateConfirmSliderVisibility()
            return
        }

        // Debounce geocoding to avoid excessive API calls while typing
        geocodingDebouncer.debounce { [weak self] in
            guard let self = self else { return }
            await self.geocodeAddress(address, isPickup: isPickup)
        }
    }

    // MARK: - Geocoding

    /// Geocodes an address (converts text to coordinates)
    private func geocodeAddress(_ address: String, isPickup: Bool) async {
        await viewModel.geocodeAddress(address, isPickup: isPickup)

        // Sync with map after geocoding
        if let location = isPickup ? viewModel.pickupLocation : viewModel.destinationLocation {
            if isPickup {
                mapViewModel.updatePickupLocation(location.coordinate, name: location.name)
            } else {
                mapViewModel.updateDestinationLocation(location.coordinate, name: location.name)
            }
        }

        updateConfirmSliderVisibility()
    }

    // MARK: - Route Calculation

    /// Calculates route if both locations are set
    private func calculateRouteIfReady() async {
        guard viewModel.pickupLocation != nil,
              viewModel.destinationLocation != nil else {
            return
        }

        await viewModel.calculateRoute()

        // Update map with route
        if let route = viewModel.route {
            mapViewModel.updateRouteFromMKRoute(route)
        }
    }

    // MARK: - Ride Confirmation

    /// Validates and confirms the ride request
    /// - Returns: Tuple of (pickup, destination) if successful, nil if validation failed
    func confirmRide() -> (pickup: LocationPoint, destination: LocationPoint)? {
        // Validate locations exist
        guard let pickup = viewModel.pickupLocation else {
            viewModel.error = .invalidPickupLocation
            return nil
        }

        guard let destination = viewModel.destinationLocation else {
            viewModel.error = .invalidDestinationLocation
            return nil
        }

        // Run validation if enabled
        if configuration.enableValidation {
            guard viewModel.validateLocations() else {
                return nil
            }
        }

        // Update state to requested
        viewModel.rideState = .rideRequested

        return (pickup, destination)
    }

    // MARK: - State Management

    /// Resets all state to initial values
    func reset() {
        viewModel.reset()
        mapViewModel.pickupLocation = nil
        mapViewModel.destinationLocation = nil
        mapViewModel.routePolyline = nil
        showConfirmSlider = false
        geocodingDebouncer.cancel()
    }

    /// Cancels the current ride request
    func cancelRideRequest() {
        viewModel.cancelRideRequest()
    }

    /// Updates whether the confirm slider should be visible
    private func updateConfirmSliderVisibility() {
        withAnimation(.easeInOut(duration: 0.4)) {
            showConfirmSlider = viewModel.pickupLocation != nil &&
                               viewModel.destinationLocation != nil
        }
    }

    // MARK: - Location Updates

    /// Sets up automatic location updates from MapViewModel
    private func setupLocationUpdates() {
        mapViewModel.onLocationUpdate = { [weak self] location in
            guard let self = self else { return }

            // Auto-set pickup to current location if enabled and no pickup set yet
            if self.configuration.autoSetPickupLocation,
               self.viewModel.pickupLocation == nil {
                Task {
                    await self.viewModel.reverseGeocodeLocation(
                        location.coordinate,
                        isPickup: true
                    )
                }
            }
        }
    }

    // MARK: - Focus Management

    /// Call when pickup field is focused
    func didFocusPickup() {
        viewModel.rideState = .selectingPickup
    }

    /// Call when destination field is focused
    func didFocusDestination() {
        viewModel.rideState = .selectingDestination
    }
}
