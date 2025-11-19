/**
 * Driver State Machine
 * Handles state transitions and validation for driver states
 */

import Foundation

/// Manages driver state transitions with validation
struct DriverStateMachine {

    // MARK: - State Transitions

    /// Attempt to transition from one state to another
    /// Returns the new state if transition is valid, nil otherwise
    static func transition(from currentState: DriverState, to newState: DriverState) -> DriverState? {
        // Validate transition
        guard isValidTransition(from: currentState, to: newState) else {
            print("⚠️ Invalid state transition: \(currentState.statusDescription) -> \(newState.statusDescription)")
            return nil
        }

        print("✅ State transition: \(currentState.statusDescription) -> \(newState.statusDescription)")
        return newState
    }

    /// Check if a transition is valid
    static func isValidTransition(from current: DriverState, to new: DriverState) -> Bool {
        switch (current, new) {

        // From offline
        case (.offline, .loggingIn):
            return true

        // From logging in
        case (.loggingIn, .online):
            return true
        case (.loggingIn, .error):
            return true

        // From online (available)
        case (.online, .rideOffered):
            return true
        case (.online, .offline):
            return true
        case (.online, .error):
            return true

        // From ride offered
        case (.rideOffered, .headingToPickup):
            return true // accepted
        case (.rideOffered, .online):
            return true // rejected or expired
        case (.rideOffered, .error):
            return true

        // From heading to pickup
        case (.headingToPickup, .arrivedAtPickup):
            return true
        case (.headingToPickup, .error):
            return true
        case (.headingToPickup, .online):
            return true // cancelled

        // From arrived at pickup
        case (.arrivedAtPickup, .rideInProgress):
            return true // passenger picked up
        case (.arrivedAtPickup, .error):
            return true
        case (.arrivedAtPickup, .online):
            return true // cancelled

        // From ride in progress
        case (.rideInProgress, .approachingDestination):
            return true
        case (.rideInProgress, .rideCompleted):
            return true // skip approaching if very short ride
        case (.rideInProgress, .error):
            return true

        // From approaching destination
        case (.approachingDestination, .rideCompleted):
            return true
        case (.approachingDestination, .error):
            return true

        // From ride completed
        case (.rideCompleted, .online):
            return true
        case (.rideCompleted, .offline):
            return true

        // From error
        case (.error(_, let previousState), _):
            // Can transition to previous state or offline
            if previousState != nil, case .offline = new {
                return true
            }
            if previousState != nil, case .online = new {
                return true
            }
            return false

        default:
            return false
        }
    }

    // MARK: - State Helpers

    /// Login driver
    static func login(driverId: String) -> DriverState {
        return .loggingIn
    }

    /// Complete login and go online
    static func loginComplete(stats: DriverStats) -> DriverState {
        return .online(stats: stats)
    }

    /// Go offline
    static func goOffline() -> DriverState {
        return .offline
    }

    /// Receive ride offer
    static func receiveRideOffer(request: RideRequest, currentStats: DriverStats) -> DriverState {
        return .rideOffered(request: request, stats: currentStats)
    }

    /// Accept ride
    static func acceptRide(ride: ActiveRide, stats: DriverStats) -> DriverState {
        return .headingToPickup(ride: ride, stats: stats)
    }

    /// Reject ride
    static func rejectRide(stats: DriverStats) -> DriverState {
        return .online(stats: stats)
    }

    /// Arrive at pickup
    static func arriveAtPickup(ride: ActiveRide, stats: DriverStats) -> DriverState {
        return .arrivedAtPickup(ride: ride, stats: stats)
    }

    /// Pick up passenger
    static func pickupPassenger(ride: ActiveRide, stats: DriverStats) -> DriverState {
        return .rideInProgress(ride: ride, stats: stats)
    }

    /// Approach destination
    static func approachDestination(ride: ActiveRide, stats: DriverStats) -> DriverState {
        return .approachingDestination(ride: ride, stats: stats)
    }

    /// Complete ride
    static func completeRide(summary: RideSummary, updatedStats: DriverStats) -> DriverState {
        return .rideCompleted(summary: summary, stats: updatedStats)
    }

    /// Finish ride summary and return to online
    static func finishRideSummary(stats: DriverStats) -> DriverState {
        return .online(stats: stats)
    }

    /// Handle error
    static func error(message: String, previousState: DriverState?) -> DriverState {
        return .error(message: message, previousState: previousState)
    }

    /// Update driver stats in current state
    static func updateStats(in state: DriverState, newStats: DriverStats) -> DriverState {
        switch state {
        case .online:
            return .online(stats: newStats)
        case .rideOffered(let request, _):
            return .rideOffered(request: request, stats: newStats)
        case .headingToPickup(let ride, _):
            return .headingToPickup(ride: ride, stats: newStats)
        case .arrivedAtPickup(let ride, _):
            return .arrivedAtPickup(ride: ride, stats: newStats)
        case .rideInProgress(let ride, _):
            return .rideInProgress(ride: ride, stats: newStats)
        case .approachingDestination(let ride, _):
            return .approachingDestination(ride: ride, stats: newStats)
        case .rideCompleted(let summary, _):
            return .rideCompleted(summary: summary, stats: newStats)
        default:
            return state
        }
    }

    /// Update active ride in current state
    static func updateRide(in state: DriverState, newRide: ActiveRide) -> DriverState {
        guard let stats = state.currentStats else { return state }

        switch state {
        case .headingToPickup:
            return .headingToPickup(ride: newRide, stats: stats)
        case .arrivedAtPickup:
            return .arrivedAtPickup(ride: newRide, stats: stats)
        case .rideInProgress:
            return .rideInProgress(ride: newRide, stats: stats)
        case .approachingDestination:
            return .approachingDestination(ride: newRide, stats: stats)
        default:
            return state
        }
    }
}
