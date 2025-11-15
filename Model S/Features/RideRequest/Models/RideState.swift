//
//  RideState.swift
//  Model S
//
//  Ride flow state machine with associated values
//  Each state carries its own data, making illegal states unrepresentable
//

import Foundation

/// Represents all possible states in the ride request flow
/// Uses associated values to keep state and data together
indirect enum RideState {
    /// Initial state - no locations selected
    case idle

    /// User is selecting pickup and/or destination locations
    case selectingLocations(pickup: LocationPoint?, destination: LocationPoint?)

    /// Route has been calculated and is ready for confirmation
    case routeReady(pickup: LocationPoint, destination: LocationPoint, route: RouteInfo)

    /// Ride request is being submitted to the backend
    case submittingRequest(pickup: LocationPoint, destination: LocationPoint)

    /// Searching for an available driver
    case searchingForDriver(rideId: String, pickup: LocationPoint, destination: LocationPoint)

    /// Driver has been found and assigned
    case driverAssigned(rideId: String, driver: DriverInfo, pickup: LocationPoint, destination: LocationPoint)

    /// Driver is en route to pickup location
    case driverEnRoute(rideId: String, driver: DriverInfo, eta: TimeInterval, pickup: LocationPoint, destination: LocationPoint)

    /// An error occurred
    case error(RideRequestError, previousState: RideState?)

    // MARK: - Computed Properties

    /// Whether the slider should be shown
    var shouldShowConfirmSlider: Bool {
        if case .routeReady = self {
            return true
        }
        return false
    }

    /// Whether we're in an active ride flow
    var isActiveRide: Bool {
        switch self {
        case .submittingRequest, .searchingForDriver, .driverAssigned, .driverEnRoute:
            return true
        default:
            return false
        }
    }

    /// Current ride ID if in an active ride
    var rideId: String? {
        switch self {
        case .searchingForDriver(let rideId, _, _),
             .driverAssigned(let rideId, _, _, _),
             .driverEnRoute(let rideId, _, _, _, _):
            return rideId
        default:
            return nil
        }
    }

    /// Current driver if assigned
    var driver: DriverInfo? {
        switch self {
        case .driverAssigned(_, let driver, _, _),
             .driverEnRoute(_, let driver, _, _, _):
            return driver
        default:
            return nil
        }
    }

    /// Estimated arrival time if driver is en route
    var estimatedArrival: TimeInterval? {
        if case .driverEnRoute(_, _, let eta, _, _) = self {
            return eta
        }
        return nil
    }

    /// Current pickup location
    var pickupLocation: LocationPoint? {
        switch self {
        case .selectingLocations(let pickup, _):
            return pickup
        case .routeReady(let pickup, _, _),
             .submittingRequest(let pickup, _),
             .searchingForDriver(_, let pickup, _),
             .driverAssigned(_, _, let pickup, _),
             .driverEnRoute(_, _, _, let pickup, _):
            return pickup
        default:
            return nil
        }
    }

    /// Current destination location
    var destinationLocation: LocationPoint? {
        switch self {
        case .selectingLocations(_, let destination):
            return destination
        case .routeReady(_, let destination, _),
             .submittingRequest(_, let destination),
             .searchingForDriver(_, _, let destination),
             .driverAssigned(_, _, _, let destination),
             .driverEnRoute(_, _, _, _, let destination):
            return destination
        default:
            return nil
        }
    }

    /// Current route info if available
    var routeInfo: RouteInfo? {
        if case .routeReady(_, _, let route) = self {
            return route
        }
        return nil
    }

    // MARK: - Helper Methods

    /// Get the legacy RideRequestState for backward compatibility
    var legacyState: RideRequestState {
        switch self {
        case .idle:
            return .selectingPickup
        case .selectingLocations(let pickup, let destination):
            if pickup == nil {
                return .selectingPickup
            } else if destination == nil {
                return .selectingDestination
            } else {
                return .selectingDestination
            }
        case .routeReady:
            return .routeReady
        case .submittingRequest:
            return .rideRequested
        case .searchingForDriver:
            return .searchingForDriver
        case .driverAssigned:
            return .driverFound
        case .driverEnRoute:
            return .driverEnRoute
        case .error:
            return .selectingPickup
        }
    }
}

/// Information about a calculated route
struct RouteInfo: Equatable {
    let distance: Double // meters
    let estimatedTravelTime: TimeInterval // seconds
    let polyline: String // Encoded polyline or identifier

    static func == (lhs: RouteInfo, rhs: RouteInfo) -> Bool {
        lhs.distance == rhs.distance &&
        lhs.estimatedTravelTime == rhs.estimatedTravelTime &&
        lhs.polyline == rhs.polyline
    }
}

// MARK: - Equatable Conformance

extension RideState: Equatable {
    static func == (lhs: RideState, rhs: RideState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true

        case (.selectingLocations(let lhsPickup, let lhsDestination),
              .selectingLocations(let rhsPickup, let rhsDestination)):
            return lhsPickup == rhsPickup && lhsDestination == rhsDestination

        case (.routeReady(let lhsPickup, let lhsDestination, let lhsRoute),
              .routeReady(let rhsPickup, let rhsDestination, let rhsRoute)):
            return lhsPickup == rhsPickup && lhsDestination == rhsDestination && lhsRoute == rhsRoute

        case (.submittingRequest(let lhsPickup, let lhsDestination),
              .submittingRequest(let rhsPickup, let rhsDestination)):
            return lhsPickup == rhsPickup && lhsDestination == rhsDestination

        case (.searchingForDriver(let lhsRideId, let lhsPickup, let lhsDestination),
              .searchingForDriver(let rhsRideId, let rhsPickup, let rhsDestination)):
            return lhsRideId == rhsRideId && lhsPickup == rhsPickup && lhsDestination == rhsDestination

        case (.driverAssigned(let lhsRideId, let lhsDriver, let lhsPickup, let lhsDestination),
              .driverAssigned(let rhsRideId, let rhsDriver, let rhsPickup, let rhsDestination)):
            return lhsRideId == rhsRideId && lhsDriver == rhsDriver && lhsPickup == rhsPickup && lhsDestination == rhsDestination

        case (.driverEnRoute(let lhsRideId, let lhsDriver, let lhsEta, let lhsPickup, let lhsDestination),
              .driverEnRoute(let rhsRideId, let rhsDriver, let rhsEta, let rhsPickup, let rhsDestination)):
            return lhsRideId == rhsRideId && lhsDriver == rhsDriver && lhsEta == rhsEta && lhsPickup == rhsPickup && lhsDestination == rhsDestination

        case (.error(let lhsError, let lhsPrevious), .error(let rhsError, let rhsPrevious)):
            // Compare error types (ignore associated values for .unknown case)
            let errorsMatch = errorTypesMatch(lhsError, rhsError)
            // Recursively compare previous states
            let previousMatch = (lhsPrevious == nil && rhsPrevious == nil) ||
                               (lhsPrevious != nil && rhsPrevious != nil && lhsPrevious! == rhsPrevious!)
            return errorsMatch && previousMatch

        default:
            return false
        }
    }

    /// Helper to compare error types (ignoring associated Error values)
    private static func errorTypesMatch(_ lhs: RideRequestError, _ rhs: RideRequestError) -> Bool {
        switch (lhs, rhs) {
        case (.locationPermissionDenied, .locationPermissionDenied),
             (.locationServicesDisabled, .locationServicesDisabled),
             (.locationUnavailable, .locationUnavailable),
             (.geocodingFailed, .geocodingFailed),
             (.routeCalculationFailed, .routeCalculationFailed),
             (.invalidPickupLocation, .invalidPickupLocation),
             (.invalidDestinationLocation, .invalidDestinationLocation),
             (.networkUnavailable, .networkUnavailable),
             (.rideRequestFailed, .rideRequestFailed):
            return true
        case (.unknown, .unknown):
            // We can't compare Error values, so consider all .unknown cases equal
            return true
        default:
            return false
        }
    }
}
