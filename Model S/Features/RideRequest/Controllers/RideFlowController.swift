//
//  RideFlowController.swift
//  Model S
//
//  Single source of truth for ride request flow state
//  Manages all state transitions through a state machine
//

import Foundation
import Combine

/// Controls the entire ride request flow with a clean state machine
/// This is the ONLY object that owns ride state - no nested ObservableObjects
@MainActor
class RideFlowController: ObservableObject {

    // MARK: - Published State (Single Source of Truth)

    /// Current state of the ride flow - the only source of truth
    @Published private(set) var currentState: RideState = .idle

    // MARK: - Dependencies

    private let stateMachine: RideStateMachine
    private let rideService: RideRequestService
    private let routeService: RouteCalculationService
    private let geocodingService: GeocodingService

    // MARK: - Initialization

    init(
        rideService: RideRequestService? = nil,
        routeService: RouteCalculationService? = nil,
        geocodingService: GeocodingService? = nil
    ) {
        self.stateMachine = RideStateMachine()
        self.rideService = rideService ?? RideRequestServiceFactory.shared.createRideRequestService(useMock: true)
        self.routeService = routeService ?? MapServiceFactory.shared.createRouteCalculationService()
        self.geocodingService = geocodingService ?? MapServiceFactory.shared.createGeocodingService()
    }

    // MARK: - State Transitions

    /// Start fresh ride request flow
    func startFlow() {
        transition(to: .selectingLocations(pickup: nil, destination: nil))
    }

    /// Update pickup location
    func updatePickup(_ location: LocationPoint?) {
        let destination = currentState.destinationLocation
        transition(to: .selectingLocations(pickup: location, destination: destination))

        // Auto-calculate route if both locations are set
        if let pickup = location, let destination = destination {
            Task {
                await calculateRoute(from: pickup, to: destination)
            }
        }
    }

    /// Update destination location
    func updateDestination(_ location: LocationPoint?) {
        let pickup = currentState.pickupLocation
        transition(to: .selectingLocations(pickup: pickup, destination: location))

        // Auto-calculate route if both locations are set
        if let pickup = pickup, let destination = location {
            Task {
                await calculateRoute(from: pickup, to: destination)
            }
        }
    }

    /// Calculate route between two locations
    func calculateRoute(from pickup: LocationPoint, to destination: LocationPoint) async {
        do {
            let result = try await routeService.calculateRoute(
                from: pickup.coordinate,
                to: destination.coordinate
            )

            let routeInfo = RouteInfo(
                distance: result.distance,
                estimatedTravelTime: result.expectedTravelTime,
                polyline: "\(result.polyline)" // Convert to string identifier
            )

            transition(to: .routeReady(pickup: pickup, destination: destination, route: routeInfo))

        } catch {
            transition(to: .error(.routeCalculationFailed, previousState: currentState))
        }
    }

    /// Start the ride request (called when user confirms)
    func requestRide() async {
        guard case .routeReady(let pickup, let destination, _) = currentState else {
            print("❌ Cannot request ride - not in routeReady state")
            return
        }

        // Transition to submitting
        transition(to: .submittingRequest(pickup: pickup, destination: destination))

        do {
            // Submit ride request
            let result = try await rideService.requestRide(pickup: pickup, destination: destination)

            // Transition to searching
            transition(to: .searchingForDriver(
                rideId: result.rideId,
                pickup: pickup,
                destination: destination
            ))

            // Wait for driver assignment
            let statusResult = try await rideService.getRideStatus(rideId: result.rideId)

            // Transition to driver assigned
            if let driver = statusResult.driver,
               let eta = statusResult.estimatedArrival {
                transition(to: .driverAssigned(
                    rideId: result.rideId,
                    driver: driver,
                    pickup: pickup,
                    destination: destination
                ))

                // Wait a moment, then transition to en route
                try await Task.sleep(nanoseconds: UInt64(2.0 * 1_000_000_000))

                transition(to: .driverEnRoute(
                    rideId: result.rideId,
                    driver: driver,
                    eta: eta,
                    pickup: pickup,
                    destination: destination
                ))
            }

        } catch {
            transition(to: .error(.rideRequestFailed, previousState: currentState))
        }
    }

    /// Cancel the current ride
    func cancelRide() async {
        guard let rideId = currentState.rideId else {
            reset()
            return
        }

        do {
            try await rideService.cancelRide(rideId: rideId)
            reset()
        } catch {
            transition(to: .error(.rideRequestFailed, previousState: currentState))
        }
    }

    /// Reset to initial state
    func reset() {
        transition(to: .idle)
    }

    // MARK: - Private Helpers

    /// Perform a validated state transition
    private func transition(to newState: RideState) {
        currentState = stateMachine.transition(from: currentState, to: newState)
    }

    // MARK: - Computed Properties for UI

    /// Whether confirm slider should be visible
    var shouldShowConfirmSlider: Bool {
        currentState.shouldShowConfirmSlider
    }

    /// Whether we're in an active ride
    var isActiveRide: Bool {
        currentState.isActiveRide
    }

    /// Current driver info
    var driver: DriverInfo? {
        currentState.driver
    }

    /// Estimated arrival time
    var estimatedArrival: TimeInterval? {
        currentState.estimatedArrival
    }

    /// Pickup location
    var pickupLocation: LocationPoint? {
        currentState.pickupLocation
    }

    /// Destination location
    var destinationLocation: LocationPoint? {
        currentState.destinationLocation
    }

    /// Route info
    var routeInfo: RouteInfo? {
        currentState.routeInfo
    }

    /// Current error if in error state
    var currentError: RideRequestError? {
        if case .error(let error, _) = currentState {
            return error
        }
        return nil
    }

    /// Legacy state for backward compatibility
    var legacyState: RideRequestState {
        currentState.legacyState
    }

    /// Whether we're currently loading (submitting request or calculating route)
    var isLoading: Bool {
        if case .submittingRequest = currentState {
            return true
        }
        return false
    }

    /// Clear current error and return to previous state or idle
    func clearError() {
        if case .error(_, let previousState) = currentState {
            if let previous = previousState {
                transition(to: previous)
            } else {
                transition(to: .idle)
            }
        }
    }
}
