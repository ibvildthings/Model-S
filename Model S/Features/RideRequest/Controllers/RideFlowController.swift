//
//  RideFlowController.swift
//  Model S
//
//  Single source of truth for ride request flow state
//  Manages all state transitions through a state machine
//

import Foundation
import Combine
import MapKit

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

    // MARK: - Route Storage

    /// Stores the actual MKRoute for map display
    private(set) var currentMKRoute: MKRoute?

    /// Timer for polling backend ride status
    private var statusPollingTimer: Timer?

    // MARK: - Initialization

    init(
        rideService: RideRequestService? = nil,
        routeService: RouteCalculationService? = nil,
        geocodingService: GeocodingService? = nil
    ) {
        self.stateMachine = RideStateMachine()
        // 🌐 Using REAL backend server (change useMock to true for mock mode)
        self.rideService = rideService ?? RideRequestServiceFactory.shared.createRideRequestService(useMock: false)
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

            // Store the MKRoute for map display (cast from Any)
            if let mkRoute = result.polyline as? MKRoute {
                currentMKRoute = mkRoute
            }

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

    /// Calculate driver route from driver's location to pickup
    /// Returns the MKRoute if successful, nil otherwise
    func calculateDriverRoute(from driverLocation: CLLocationCoordinate2D, to pickup: CLLocationCoordinate2D) async -> MKRoute? {
        do {
            let result = try await routeService.calculateRoute(
                from: driverLocation,
                to: pickup
            )

            // Return the MKRoute for driver animation
            return result.polyline as? MKRoute
        } catch {
            print("❌ Failed to calculate driver route: \(error)")
            return nil
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

            // Poll for driver assignment (backend takes a few seconds to match)
            var statusResult: RideRequestResult
            var attempts = 0
            let maxAttempts = 30 // Max 30 seconds

            repeat {
                attempts += 1
                print("🔄 Polling for driver assignment (attempt \(attempts))...")

                // Wait 1 second between polls
                try await Task.sleep(nanoseconds: 1_000_000_000)

                statusResult = try await rideService.getRideStatus(rideId: result.rideId)

                // Break if driver found
                if statusResult.driver != nil {
                    print("✅ Driver found after \(attempts) attempts!")
                    break
                }
            } while attempts < maxAttempts

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

                // Start polling backend for ride status updates
                startPollingRideStatus(rideId: result.rideId, pickup: pickup, destination: destination)

                // NOTE: Transitions to driverArriving, rideInProgress, approachingDestination,
                // and rideCompleted are now handled by polling the backend ride status.
                // The backend simulator will update the ride status as the driver progresses.
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
            stopPollingRideStatus()
            try await rideService.cancelRide(rideId: rideId)
            reset()
        } catch {
            transition(to: .error(.rideRequestFailed, previousState: currentState))
        }
    }

    /// Reset to initial state
    func reset() {
        stopPollingRideStatus()
        currentMKRoute = nil
        transition(to: .idle)
    }

    /// Start polling backend for ride status updates
    private func startPollingRideStatus(rideId: String, pickup: LocationPoint, destination: LocationPoint) {
        print("🔄 Starting ride status polling for ride \(rideId)")

        // Stop any existing polling
        stopPollingRideStatus()

        // Poll every 2 seconds
        statusPollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                await self.checkRideStatus(rideId: rideId, pickup: pickup, destination: destination)
            }
        }

        // Fire immediately
        Task { @MainActor in
            await checkRideStatus(rideId: rideId, pickup: pickup, destination: destination)
        }
    }

    /// Stop polling for ride status
    private func stopPollingRideStatus() {
        statusPollingTimer?.invalidate()
        statusPollingTimer = nil
        print("🔄 Stopped ride status polling")
    }

    /// Check ride status from backend and update state accordingly
    private func checkRideStatus(rideId: String, pickup: LocationPoint, destination: LocationPoint) async {
        do {
            let statusResult = try await rideService.getRideStatus(rideId: rideId)

            guard let driver = statusResult.driver else {
                return
            }

            // Map backend status to frontend state
            switch statusResult.status {
            case "assigned":
                // Driver assigned but not yet en route
                if case .searchingForDriver = currentState {
                    transition(to: .driverAssigned(
                        rideId: rideId,
                        driver: driver,
                        pickup: pickup,
                        destination: destination
                    ))
                }

            case "enRoute":
                // Driver is on the way to pickup
                if case .driverAssigned = currentState {
                    transition(to: .driverEnRoute(
                        rideId: rideId,
                        driver: driver,
                        eta: statusResult.estimatedArrival ?? 0,
                        pickup: pickup,
                        destination: destination
                    ))
                }

            case "arriving":
                // Driver is arriving at pickup (< 1 min away)
                if case .driverEnRoute = currentState {
                    print("🚗 Backend says driver is arriving")
                    transition(to: .driverArriving(
                        rideId: rideId,
                        driver: driver,
                        pickup: pickup,
                        destination: destination
                    ))
                }

            case "inProgress":
                // Driver picked up passenger, heading to destination
                if case .driverArriving = currentState {
                    print("🚗 Backend says ride is in progress")
                    transition(to: .rideInProgress(
                        rideId: rideId,
                        driver: driver,
                        eta: statusResult.estimatedArrival ?? 0,
                        pickup: pickup,
                        destination: destination
                    ))
                } else if case .driverEnRoute = currentState {
                    // Sometimes we might skip arriving state if it's too fast
                    print("🚗 Backend says ride is in progress (skipped arriving)")
                    transition(to: .rideInProgress(
                        rideId: rideId,
                        driver: driver,
                        eta: statusResult.estimatedArrival ?? 0,
                        pickup: pickup,
                        destination: destination
                    ))
                }

            case "approaching":
                // Approaching destination
                if case .rideInProgress = currentState {
                    print("🏁 Backend says approaching destination")
                    transition(to: .approachingDestination(
                        rideId: rideId,
                        driver: driver,
                        pickup: pickup,
                        destination: destination
                    ))
                }

            case "completed":
                // Ride completed
                print("✅ Backend says ride is completed")
                stopPollingRideStatus()
                transition(to: .rideCompleted(
                    rideId: rideId,
                    driver: driver,
                    pickup: pickup,
                    destination: destination
                ))

            default:
                break
            }

        } catch {
            print("⚠️ Error polling ride status: \(error)")
            // Don't transition to error state, just keep polling
        }
    }

    /// Manually transition to driver arriving (called by animation callback)
    func transitionToDriverArriving() {
        guard case .driverEnRoute(let rideId, let driver, _, let pickup, let destination) = currentState else {
            print("❌ Cannot transition to driverArriving from current state: \(currentState)")
            return
        }

        transition(to: .driverArriving(
            rideId: rideId,
            driver: driver,
            pickup: pickup,
            destination: destination
        ))
    }

    /// Manually transition to ride in progress (called by animation callback)
    func transitionToRideInProgress() {
        guard case .driverArriving(let rideId, let driver, let pickup, let destination) = currentState else {
            print("❌ Cannot transition to rideInProgress from current state: \(currentState)")
            return
        }

        // Get ETA to destination (reuse from previous state or default)
        let eta = estimatedArrival ?? 300 // Default 5 minutes

        transition(to: .rideInProgress(
            rideId: rideId,
            driver: driver,
            eta: eta,
            pickup: pickup,
            destination: destination
        ))
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
