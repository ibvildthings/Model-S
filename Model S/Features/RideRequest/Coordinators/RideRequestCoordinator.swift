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
import Combine

/// Coordinates the entire ride request flow
/// Now uses RideFlowController for clean state management
@MainActor
class RideRequestCoordinator: ObservableObject {
    // MARK: - Published State

    /// Ride flow controller - single source of truth for ride state
    @Published private(set) var flowController: RideFlowController

    /// Map display state (published for view observation)
    @Published private(set) var mapViewModel: MapViewModel

    // MARK: - Private Dependencies

    private let configuration: RideRequestConfiguration
    private let geocodingService: GeocodingService
    private let geocodingDebouncer: Debouncer
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Creates a coordinator with the given configuration
    /// - Parameter configuration: UI and feature configuration
    init(configuration: RideRequestConfiguration = .default) {
        self.configuration = configuration
        self.flowController = RideFlowController()
        self.mapViewModel = MapViewModel()
        self.geocodingService = MapServiceFactory.shared.createGeocodingService()
        self.geocodingDebouncer = Debouncer(delay: TimingConstants.geocodingDebounceDelay)

        setupLocationUpdates()

        // Observe state changes (use $currentState to get value AFTER it changes)
        flowController.$currentState.sink { [weak self] newState in
            self?.objectWillChange.send()
            self?.handleStateChange(newState)
        }.store(in: &cancellables)

        // Forward mapViewModel changes to coordinator's objectWillChange
        mapViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        // Start the flow
        flowController.startFlow()
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

        // Update flow controller state
        if isPickup {
            flowController.updatePickup(locationPoint)
            mapViewModel.updatePickupLocation(coordinate, name: name)
        } else {
            flowController.updateDestination(locationPoint)
            mapViewModel.updateDestinationLocation(coordinate, name: name)
        }

        // Update map with route if it was calculated
        if let route = flowController.routeInfo {
            // Note: We'll need to update mapViewModel when route is ready
            // For now, the route calculation happens in flowController
        }
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
                flowController.updatePickup(nil)
                mapViewModel.pickupLocation = nil
            } else {
                flowController.updateDestination(nil)
                mapViewModel.destinationLocation = nil
            }
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
        do {
            let (coordinate, formattedAddress) = try await geocodingService.geocode(address: address)
            let locationPoint = LocationPoint(coordinate: coordinate, name: formattedAddress)

            // Update flow controller
            if isPickup {
                flowController.updatePickup(locationPoint)
                mapViewModel.updatePickupLocation(coordinate, name: formattedAddress)
            } else {
                flowController.updateDestination(locationPoint)
                mapViewModel.updateDestinationLocation(coordinate, name: formattedAddress)
            }
        } catch {
            // Handle geocoding error
            print("Geocoding failed: \(error)")
        }
    }

    // MARK: - Ride Confirmation

    /// Validates and confirms the ride request
    /// - Returns: Tuple of (pickup, destination) if successful, nil if validation failed
    func confirmRide() -> (pickup: LocationPoint, destination: LocationPoint)? {
        // Validate locations exist
        guard let pickup = flowController.pickupLocation else {
            return nil
        }

        guard let destination = flowController.destinationLocation else {
            return nil
        }

        return (pickup, destination)
    }

    /// Start the ride request flow (call this from an async context)
    func startRideRequest() async {
        await flowController.requestRide()
    }

    /// Cancels the current active ride
    func cancelCurrentRide() {
        Task { @MainActor in
            await flowController.cancelRide()
        }
    }

    // MARK: - State Management

    /// Resets all state to initial values
    func reset() {
        flowController.reset()
        mapViewModel.pickupLocation = nil
        mapViewModel.destinationLocation = nil
        mapViewModel.routePolyline = nil
        geocodingDebouncer.cancel()
    }

    /// Cancels the current ride request
    func cancelRideRequest() {
        Task { @MainActor in
            await flowController.cancelRide()
        }
    }

    // MARK: - Computed Properties

    /// Whether confirm slider should be visible
    var shouldShowConfirmSlider: Bool {
        flowController.shouldShowConfirmSlider
    }

    // MARK: - Location Updates

    /// Sets up automatic location updates from MapViewModel
    private func setupLocationUpdates() {
        mapViewModel.onLocationUpdate = { [weak self] location in
            guard let self = self else { return }

            // Auto-set pickup to current location if enabled and no pickup set yet
            if self.configuration.autoSetPickupLocation,
               self.flowController.pickupLocation == nil {
                Task {
                    do {
                        let address = try await self.geocodingService.reverseGeocode(coordinate: location.coordinate)
                        let locationPoint = LocationPoint(coordinate: location.coordinate, name: address)
                        self.flowController.updatePickup(locationPoint)
                        self.mapViewModel.updatePickupLocation(location.coordinate, name: address)
                    } catch {
                        print("Reverse geocoding failed: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - Focus Management

    /// Call when pickup field is focused
    func didFocusPickup() {
        // State management handled by flowController
    }

    /// Call when destination field is focused
    func didFocusDestination() {
        // State management handled by flowController
    }

    // MARK: - State Change Handling

    /// Handles state transitions and triggers appropriate actions (like driver animation)
    private func handleStateChange(_ currentState: RideState) {
        print("🔄 handleStateChange called with state: \(currentState)")

        // Ensure map always has pickup/destination from current state
        if let pickup = flowController.pickupLocation {
            mapViewModel.updatePickupLocation(pickup.coordinate, name: pickup.name)
        }
        if let destination = flowController.destinationLocation {
            mapViewModel.updateDestinationLocation(destination.coordinate, name: destination.name)
        }

        switch currentState {
        case .routeReady:
            print("🔄 Handling .routeReady")
            // Update map with the calculated route
            if let mkRoute = flowController.currentMKRoute {
                print("📍 Updating map with calculated route")
                mapViewModel.updateRouteFromMKRoute(mkRoute)
            }

        case .driverEnRoute(_, let driver, _, let pickup, _):
            print("🔄 Handling .driverEnRoute")
            // Start animating driver if not already animating
            if mapViewModel.driverLocation == nil {
                print("🔄 Driver location is nil, setting up animation")

                // REMOVED: Animation callbacks no longer trigger state changes
                // Backend polling now controls all state transitions
                // Animation is purely visual

                // Calculate and set driver's route from their location to pickup
                if let driverLocation = driver.currentLocation {
                    Task {
                        print("🚗 Calculating driver route from \(driverLocation) to \(pickup.coordinate)")
                        if let driverRoute = await flowController.calculateDriverRoute(
                            from: driverLocation,
                            to: pickup.coordinate
                        ) {
                            mapViewModel.updateDriverRoute(driverRoute)
                            print("🚗 Starting driver animation from driver's actual location: \(driverLocation)")
                            mapViewModel.startDriverAnimation(from: driverLocation)
                        } else {
                            print("❌ Failed to calculate driver route, falling back to default animation")
                            mapViewModel.startDriverAnimation(from: driverLocation)
                        }
                    }
                } else {
                    print("⚠️ Driver has no location, starting animation from route beginning")
                    mapViewModel.startDriverAnimation()
                }
            } else {
                print("🔄 Driver location already set: \(mapViewModel.driverLocation!)")
            }

        case .driverArriving(_, _, _, _):
            // Animation continues, waiting for driver to reach pickup
            print("🚗 Driver arriving soon...")
            break

        case .rideInProgress(_, let driver, _, let pickup, let destination):
            // Driver picked up passenger, now animate to destination
            print("🔄 Handling .rideInProgress")

            // Only start destination animation if we haven't already
            if mapViewModel.driverRoutePolyline != nil {
                print("🚙 Passenger picked up, starting route to destination")

                // Switch viewport to track driver + destination
                mapViewModel.switchToDestinationTracking()

                // Calculate route from pickup to destination
                if let mkRoute = flowController.currentMKRoute {
                    // We already have the pickup-to-destination route
                    mapViewModel.updateDriverRoute(mkRoute)

                    // Start animation from pickup location
                    print("🚗 Starting drive to destination from pickup: \(pickup.coordinate)")
                    mapViewModel.startDriverAnimation(from: pickup.coordinate)
                } else {
                    print("⚠️ No route available for destination animation")
                }
            }
            break

        case .approachingDestination(_, _, _, _):
            // Animation continues toward destination
            print("🏁 Approaching destination...")
            break

        case .rideCompleted:
            // Ride finished, clean up
            print("✅ Ride completed, clearing driver animation")
            mapViewModel.clearDriverLocation()
            break

        case .idle, .selectingLocations:
            print("🔄 Handling .idle or .selectingLocations")
            // Clear driver location and route when going back to initial states
            mapViewModel.clearDriverLocation()
            mapViewModel.routePolyline = nil

        default:
            print("🔄 Handling default case (submittingRequest, searchingForDriver, driverAssigned, etc.)")
            break
        }
    }

    // REMOVED: Manual transition methods no longer needed
    // Backend polling now controls all state transitions
    // Animation is purely visual and doesn't trigger state changes
}
