/**
 * Driver State Machine
 * Defines all possible states for a driver during their session
 */

import Foundation

/// Represents the current state of a driver
enum DriverState: Equatable {
    /// Driver is offline (not logged in)
    case offline

    /// Driver is logging in
    case loggingIn

    /// Driver is online and available for rides
    case online(stats: DriverStats)

    /// Driver received a ride request
    case rideOffered(request: RideRequest, stats: DriverStats)

    /// Driver accepted ride and heading to pickup
    case headingToPickup(ride: ActiveRide, stats: DriverStats)

    /// Driver arrived at pickup location
    case arrivedAtPickup(ride: ActiveRide, stats: DriverStats)

    /// Ride in progress (passenger picked up)
    case rideInProgress(ride: ActiveRide, stats: DriverStats)

    /// Approaching destination
    case approachingDestination(ride: ActiveRide, stats: DriverStats)

    /// Ride completed, showing summary
    case rideCompleted(summary: RideSummary, stats: DriverStats)

    /// Error occurred
    case error(message: String, previousState: DriverState?)

    // MARK: - Computed Properties

    var isOnline: Bool {
        switch self {
        case .offline, .loggingIn, .error:
            return false
        default:
            return true
        }
    }

    var hasActiveRide: Bool {
        switch self {
        case .headingToPickup, .arrivedAtPickup, .rideInProgress, .approachingDestination:
            return true
        default:
            return false
        }
    }

    var currentStats: DriverStats? {
        switch self {
        case .online(let stats),
             .rideOffered(_, let stats),
             .headingToPickup(_, let stats),
             .arrivedAtPickup(_, let stats),
             .rideInProgress(_, let stats),
             .approachingDestination(_, let stats),
             .rideCompleted(_, let stats):
            return stats
        default:
            return nil
        }
    }

    var currentRide: ActiveRide? {
        switch self {
        case .headingToPickup(let ride, _),
             .arrivedAtPickup(let ride, _),
             .rideInProgress(let ride, _),
             .approachingDestination(let ride, _):
            return ride
        default:
            return nil
        }
    }

    var statusDescription: String {
        switch self {
        case .offline:
            return "Offline"
        case .loggingIn:
            return "Logging in..."
        case .online:
            return "Online - Available"
        case .rideOffered:
            return "New Ride Request"
        case .headingToPickup:
            return "Heading to Pickup"
        case .arrivedAtPickup:
            return "Arrived at Pickup"
        case .rideInProgress:
            return "Ride in Progress"
        case .approachingDestination:
            return "Approaching Destination"
        case .rideCompleted:
            return "Ride Completed"
        case .error(let message, _):
            return "Error: \(message)"
        }
    }
}

/// Driver statistics
struct DriverStats: Equatable, Codable {
    var onlineTime: TimeInterval // seconds
    var completedRides: Int
    var totalEarnings: Double
    var acceptanceRate: Double // 0-100
    var rating: Double // 0-5

    static let zero = DriverStats(
        onlineTime: 0,
        completedRides: 0,
        totalEarnings: 0,
        acceptanceRate: 100,
        rating: 5.0
    )
}

/// Ride request offered to driver
struct RideRequest: Equatable, Codable {
    let rideId: String
    let pickup: LocationPoint
    let destination: LocationPoint
    let distance: Double // meters
    let estimatedEarnings: Double
    let expiresAt: Date

    var isExpired: Bool {
        Date() > expiresAt
    }

    var timeRemaining: TimeInterval {
        max(0, expiresAt.timeIntervalSince(Date()))
    }
}

/// Active ride information
struct ActiveRide: Equatable, Codable {
    let rideId: String
    let pickup: LocationPoint
    let destination: LocationPoint
    let passenger: PassengerInfo
    var currentDriverLocation: LocationPoint
    var estimatedArrival: TimeInterval? // seconds
    var distanceToDestination: Double? // meters

    struct PassengerInfo: Equatable, Codable {
        let name: String
        let rating: Double
        let phoneNumber: String?
    }
}

/// Ride completion summary
struct RideSummary: Equatable, Codable {
    let rideId: String
    let pickup: LocationPoint
    let destination: LocationPoint
    let distance: Double // meters
    let duration: TimeInterval // seconds
    let earnings: Double
    let passengerRating: Double?
    let completedAt: Date
}

// MARK: - Location Point (if not already defined)

struct LocationPoint: Equatable, Codable {
    let lat: Double
    let lng: Double
    let address: String?

    init(lat: Double, lng: Double, address: String? = nil) {
        self.lat = lat
        self.lng = lng
        self.address = address
    }
}
