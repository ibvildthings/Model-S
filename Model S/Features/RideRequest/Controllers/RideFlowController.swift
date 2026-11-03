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

    /// Real-time driver location from backend (updated every poll)
    /// This is separate from state to avoid creating new states on every position update
    @Published private(set) var realTimeDriverLocation: CLLocationCoordinate2D?

    /// Real-time ETA from backend (updated every poll)
    /// This is separate from state to avoid triggering map re-renders on every ETA update
    @Published private(set) var realTimeETA: TimeInterval?

    // MARK: - Dependencies

    private let stateMachine: RideStateMachine
    private let rideService: RideRequestService

    /// Explicitly injected map service (tests). When nil, the provider's
    /// *current* service is used so a provider switch takes effect immediately.
    private let injectedMapService: AnyMapService?

    private var mapService: AnyMapService {
        injectedMapService ?? MapProviderService.shared.currentService
    }

    // MARK: - Route Storage

    /// Pickup → destination route geometry (provider-agnostic), set before
    /// transitioning to `.routeReady`
    private(set) var routeCoordinates: [CLLocationCoordinate2D]?

    /// Timer for polling backend ride status
    private var statusPollingTimer: Timer?

    // MARK: - Initialization

    init(
        rideService: RideRequestService? = nil,
        mapService: AnyMapService? = nil
    ) {
        self.stateMachine = RideStateMachine()
        // Backend vs. mock is decided in one place: BackendConfiguration
        self.rideService = rideService ?? BackendConfiguration.makeRideRequestService()
        self.injectedMapService = mapService
    }

    deinit {
        // Clean up timer to prevent memory leaks
        statusPollingTimer?.invalidate()
        statusPollingTimer = nil
        AppLog.debug("🧹 RideFlowController deallocated, cleaned up resources")
    }

    // MARK: - State Transitions

    /// Start fresh ride request flow
    func startFlow() {
        let noPickup: LocationPoint? = nil
        let noDestination: LocationPoint? = nil
        transition(to: .selectingLocations(pickup: noPickup, destination: noDestination))
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
            let result = try await mapService.calculateRoute(
                from: pickup.coordinate,
                to: destination.coordinate
            )

            routeCoordinates = result.coordinates
            AppLog.debug("📍 Route received with \(result.coordinates.count) coordinates")

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

    /// Calculate the route from the driver's current position to a target
    /// (pickup or destination). Returns the route geometry, or nil on failure.
    func calculateDriverRoute(from driverLocation: CLLocationCoordinate2D, to target: CLLocationCoordinate2D) async -> [CLLocationCoordinate2D]? {
        do {
            let result = try await mapService.calculateRoute(from: driverLocation, to: target)
            return result.coordinates
        } catch {
            AppLog.error("❌ Failed to calculate driver route: \(error)")
            return nil
        }
    }

    /// Start the ride request (called when user confirms)
    func requestRide() async {
        guard case .routeReady(let pickup, let destination, _) = currentState else {
            AppLog.error("❌ Cannot request ride - not in routeReady state")
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
                AppLog.debug("🔄 Polling for driver assignment (attempt \(attempts))...")

                // Wait 1 second between polls
                try await Task.sleep(nanoseconds: 1_000_000_000)

                statusResult = try await rideService.getRideStatus(rideId: result.rideId)

                // Break if driver found
                if statusResult.driver != nil {
                    AppLog.debug("✅ Driver found after \(attempts) attempts!")
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
        routeCoordinates = nil
        realTimeDriverLocation = nil // Clear backend driver position
        realTimeETA = nil // Clear backend ETA
        transition(to: .idle)
    }

    /// Start polling backend for ride status updates
    private func startPollingRideStatus(rideId: String, pickup: LocationPoint, destination: LocationPoint) {
        AppLog.debug("🔄 Starting ride status polling for ride \(rideId)")

        // Stop any existing polling
        stopPollingRideStatus()

        // Poll every 1 second for smoother driver movement
        // Backend updates driver position every 500ms, so 1s polling captures most updates
        // while being more battery-efficient than matching backend's 500ms rate
        statusPollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
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
        AppLog.debug("🔄 Stopped ride status polling")
    }

    /// Check ride status from backend and update state accordingly
    private func checkRideStatus(rideId: String, pickup: LocationPoint, destination: LocationPoint) async {
        do {
            let statusResult = try await rideService.getRideStatus(rideId: rideId)

            guard let driver = statusResult.driver else {
                return
            }

            // CRITICAL: Update driver position from backend (real-time position updates)
            // This is the ONLY source of truth for driver location - backend sends real GPS data
            // Frontend should display whatever position backend sends, not calculate it locally
            if let driverLocation = driver.currentLocation {
                realTimeDriverLocation = driverLocation
                // Log position updates (every 2s) to show backend is driving the animation
                AppLog.debug("📍 Backend position update: \(String(format: "%.4f", driverLocation.latitude)), \(String(format: "%.4f", driverLocation.longitude))")
            }

            // Update real-time ETA without triggering state changes (avoids map re-renders)
            if let eta = statusResult.estimatedArrival {
                realTimeETA = eta
            }

            // Map backend status to frontend state
            switch statusResult.status {
            case .driverFound:
                // Driver assigned but not yet en route
                if case .searchingForDriver = currentState {
                    transition(to: .driverAssigned(
                        rideId: rideId,
                        driver: driver,
                        pickup: pickup,
                        destination: destination
                    ))
                }

            case .driverEnRoute:
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
                // ETA updates are handled via realTimeETA property (no state transition needed)

            case .driverArriving:
                // Driver is arriving at pickup (< 1 min away)
                if case .driverEnRoute = currentState {
                    AppLog.debug("🚗 Backend says driver is arriving")
                    transition(to: .driverArriving(
                        rideId: rideId,
                        driver: driver,
                        pickup: pickup,
                        destination: destination
                    ))
                }

            case .rideInProgress:
                // Driver picked up passenger, heading to destination
                if case .driverArriving = currentState {
                    AppLog.debug("🚗 Backend says ride is in progress")
                    transition(to: .rideInProgress(
                        rideId: rideId,
                        driver: driver,
                        eta: statusResult.estimatedArrival ?? 0,
                        pickup: pickup,
                        destination: destination
                    ))
                } else if case .driverEnRoute = currentState {
                    // Sometimes we might skip arriving state if it's too fast
                    AppLog.debug("🚗 Backend says ride is in progress (skipped arriving)")
                    transition(to: .rideInProgress(
                        rideId: rideId,
                        driver: driver,
                        eta: statusResult.estimatedArrival ?? 0,
                        pickup: pickup,
                        destination: destination
                    ))
                }
                // ETA updates are handled via realTimeETA property (no state transition needed)

            case .approachingDestination:
                // Approaching destination
                if case .rideInProgress = currentState {
                    AppLog.debug("🏁 Backend says approaching destination")
                    transition(to: .approachingDestination(
                        rideId: rideId,
                        driver: driver,
                        pickup: pickup,
                        destination: destination
                    ))
                }

            case .rideCompleted:
                // Ride completed
                AppLog.debug("✅ Backend says ride is completed")
                stopPollingRideStatus()
                transition(to: .rideCompleted(
                    rideId: rideId,
                    driver: driver,
                    pickup: pickup,
                    destination: destination
                ))

            default:
                // Other states like selectingPickup, routeReady, etc. - ignore
                break
            }

        } catch {
            AppLog.warning("⚠️ Error polling ride status: \(error)")
            // Don't transition to error state, just keep polling
        }
    }

    // REMOVED: Manual transition methods no longer needed
    // Backend polling (checkRideStatus) now controls all state transitions
    // These were previously called by animation callbacks, which are now removed

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

    /// Estimated arrival time (prefers real-time ETA over state ETA)
    var estimatedArrival: TimeInterval? {
        realTimeETA ?? currentState.estimatedArrival
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
