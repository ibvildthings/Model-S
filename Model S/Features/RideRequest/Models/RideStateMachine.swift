//
//  RideStateMachine.swift
//  Model S
//
//  Manages valid state transitions for the ride flow
//  Ensures only valid state changes are allowed
//

import Foundation

/// Manages state transitions for the ride request flow
class RideStateMachine {

    // MARK: - State Validation

    /// Check if a transition from one state to another is valid
    func canTransition(from current: RideState, to next: RideState) -> Bool {
        let validNext = validNextStates(from: current)
        return validNext.contains(where: { statesMatch($0, next) })
    }

    /// Get all valid next states from the current state
    func validNextStates(from state: RideState) -> [RideState] {
        switch state {
        case .idle:
            // Can start selecting locations or go to error
            return [
                .selectingLocations(pickup: nil, destination: nil),
                .error(.locationUnavailable, previousState: nil)
            ]

        case .selectingLocations:
            // Can update locations, calculate route, or error
            return [
                .selectingLocations(pickup: nil, destination: nil), // Update selection
                .routeReady(pickup: LocationPoint(coordinate: .init(), name: nil), destination: LocationPoint(coordinate: .init(), name: nil), route: RouteInfo(distance: 0, estimatedTravelTime: 0, polyline: "")), // Placeholder
                .idle, // Reset
                .error(.geocodingFailed, previousState: state)
            ]

        case .routeReady:
            // Can submit request or go back to selecting
            return [
                .submittingRequest(pickup: LocationPoint(coordinate: .init(), name: nil), destination: LocationPoint(coordinate: .init(), name: nil)), // Placeholder
                .selectingLocations(pickup: nil, destination: nil), // Go back
                .error(.routeCalculationFailed, previousState: state)
            ]

        case .submittingRequest:
            // Can transition to searching or error
            return [
                .searchingForDriver(rideId: "", pickup: LocationPoint(coordinate: .init(), name: nil), destination: LocationPoint(coordinate: .init(), name: nil)), // Placeholder
                .error(.rideRequestFailed, previousState: state)
            ]

        case .searchingForDriver:
            // Can find driver or error
            return [
                .driverAssigned(rideId: "", driver: DriverInfo(id: "", name: "", rating: 0, vehicleMake: "", vehicleModel: "", vehicleColor: "", licensePlate: "", photoURL: nil, phoneNumber: nil, currentLocation: nil, estimatedArrivalTime: nil), pickup: LocationPoint(coordinate: .init(), name: nil), destination: LocationPoint(coordinate: .init(), name: nil)), // Placeholder
                .error(.rideRequestFailed, previousState: state),
                .idle // Cancel request
            ]

        case .driverAssigned:
            // Can transition to en route
            return [
                .driverEnRoute(rideId: "", driver: DriverInfo(id: "", name: "", rating: 0, vehicleMake: "", vehicleModel: "", vehicleColor: "", licensePlate: "", photoURL: nil, phoneNumber: nil, currentLocation: nil, estimatedArrivalTime: nil), eta: 0, pickup: LocationPoint(coordinate: .init(), name: nil), destination: LocationPoint(coordinate: .init(), name: nil)), // Placeholder
                .error(.rideRequestFailed, previousState: state),
                .idle // Cancel ride
            ]

        case .driverEnRoute:
            // Can transition to arriving
            return [
                .driverArriving(rideId: "", driver: DriverInfo(id: "", name: "", rating: 0, vehicleMake: "", vehicleModel: "", vehicleColor: "", licensePlate: "", photoURL: nil, phoneNumber: nil, currentLocation: nil, estimatedArrivalTime: nil), pickup: LocationPoint(coordinate: .init(), name: nil), destination: LocationPoint(coordinate: .init(), name: nil)), // Placeholder
                .idle, // Cancel ride
                .error(.rideRequestFailed, previousState: state)
            ]

        case .driverArriving:
            // Can transition to ride in progress
            return [
                .rideInProgress(rideId: "", driver: DriverInfo(id: "", name: "", rating: 0, vehicleMake: "", vehicleModel: "", vehicleColor: "", licensePlate: "", photoURL: nil, phoneNumber: nil, currentLocation: nil, estimatedArrivalTime: nil), eta: 0, pickup: LocationPoint(coordinate: .init(), name: nil), destination: LocationPoint(coordinate: .init(), name: nil)), // Placeholder
                .idle, // Cancel ride
                .error(.rideRequestFailed, previousState: state)
            ]

        case .rideInProgress:
            // Can transition to approaching destination OR directly to completed
            return [
                .approachingDestination(rideId: "", driver: DriverInfo(id: "", name: "", rating: 0, vehicleMake: "", vehicleModel: "", vehicleColor: "", licensePlate: "", photoURL: nil, phoneNumber: nil, currentLocation: nil, estimatedArrivalTime: nil), pickup: LocationPoint(coordinate: .init(), name: nil), destination: LocationPoint(coordinate: .init(), name: nil)), // Placeholder
                .rideCompleted(rideId: "", driver: DriverInfo(id: "", name: "", rating: 0, vehicleMake: "", vehicleModel: "", vehicleColor: "", licensePlate: "", photoURL: nil, phoneNumber: nil, currentLocation: nil, estimatedArrivalTime: nil), pickup: LocationPoint(coordinate: .init(), name: nil), destination: LocationPoint(coordinate: .init(), name: nil)), // Allow skipping approaching if backend goes directly to completed
                .idle, // Cancel ride
                .error(.rideRequestFailed, previousState: state)
            ]

        case .approachingDestination:
            // Can transition to completed
            return [
                .rideCompleted(rideId: "", driver: DriverInfo(id: "", name: "", rating: 0, vehicleMake: "", vehicleModel: "", vehicleColor: "", licensePlate: "", photoURL: nil, phoneNumber: nil, currentLocation: nil, estimatedArrivalTime: nil), pickup: LocationPoint(coordinate: .init(), name: nil), destination: LocationPoint(coordinate: .init(), name: nil)), // Placeholder
                .idle, // Cancel ride
                .error(.rideRequestFailed, previousState: state)
            ]

        case .rideCompleted:
            // Can only reset
            return [
                .idle
            ]

        case .error:
            // From error, can go back to idle or previous state
            return [
                .idle,
                .selectingLocations(pickup: nil, destination: nil)
            ]
        }
    }

    // MARK: - State Transitions

    /// Perform a state transition with validation
    /// - Parameters:
    ///   - current: Current state
    ///   - next: Desired next state
    /// - Returns: The new state if transition is valid, or an error state if invalid
    func transition(from current: RideState, to next: RideState) -> RideState {
        guard canTransition(from: current, to: next) else {
            print("❌ Invalid transition from \(current) to \(next)")
            return .error(.unknown(NSError(domain: "RideStateMachine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid state transition"])), previousState: current)
        }

        print("✅ Transitioning: \(stateDescription(current)) → \(stateDescription(next))")
        return next
    }

    // MARK: - Helper Methods

    /// Check if two state cases match (ignoring associated values)
    private func statesMatch(_ lhs: RideState, _ rhs: RideState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.selectingLocations, .selectingLocations),
             (.routeReady, .routeReady),
             (.submittingRequest, .submittingRequest),
             (.searchingForDriver, .searchingForDriver),
             (.driverAssigned, .driverAssigned),
             (.driverEnRoute, .driverEnRoute),
             (.driverArriving, .driverArriving),
             (.rideInProgress, .rideInProgress),
             (.approachingDestination, .approachingDestination),
             (.rideCompleted, .rideCompleted),
             (.error, .error):
            return true
        default:
            return false
        }
    }

    /// Get a human-readable description of a state
    private func stateDescription(_ state: RideState) -> String {
        switch state {
        case .idle:
            return "Idle"
        case .selectingLocations:
            return "Selecting Locations"
        case .routeReady:
            return "Route Ready"
        case .submittingRequest:
            return "Submitting Request"
        case .searchingForDriver:
            return "Searching for Driver"
        case .driverAssigned:
            return "Driver Assigned"
        case .driverEnRoute:
            return "Driver En Route"
        case .driverArriving:
            return "Driver Arriving"
        case .rideInProgress:
            return "Ride In Progress"
        case .approachingDestination:
            return "Approaching Destination"
        case .rideCompleted:
            return "Ride Completed"
        case .error(let error, _):
            return "Error: \(error.localizedDescription)"
        }
    }
}
