//
//  Models.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import Foundation
import CoreLocation

// MARK: - LocationPoint

/// Represents a location point with coordinates and optional name
/// - Note: Conforms to @unchecked Sendable because CLLocationCoordinate2D is just two Doubles
struct LocationPoint: Identifiable, Equatable, Codable, @unchecked Sendable {
    /// Unique identifier for the location point
    let id: UUID

    /// Geographic coordinates of the location
    var coordinate: CLLocationCoordinate2D

    /// Optional display name for the location
    var name: String?

    // Custom initializer
    init(id: UUID = UUID(), coordinate: CLLocationCoordinate2D, name: String? = nil) {
        self.id = id
        self.coordinate = coordinate
        self.name = name
    }

    // Custom Equatable conformance since CLLocationCoordinate2D doesn't conform to Equatable by default
    static func == (lhs: LocationPoint, rhs: LocationPoint) -> Bool {
        lhs.id == rhs.id &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.name == rhs.name
    }

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        name = try container.decodeIfPresent(String.self, forKey: .name)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encodeIfPresent(name, forKey: .name)
    }
}

// MARK: - RideRequestState

/// Represents the current state of the ride request flow
enum RideRequestState {
    /// User is selecting or editing the pickup location
    case selectingPickup

    /// User is selecting or editing the destination location
    case selectingDestination

    /// Both locations are set and the route is ready to be confirmed
    case routeReady

    /// Ride has been requested and is being processed
    case rideRequested

    /// Searching for an available driver
    case searchingForDriver

    /// A driver has been found and assigned
    case driverFound

    /// Driver is en route to pickup location
    case driverEnRoute

    /// Driver is arriving at pickup location (< 1 min away)
    case driverArriving

    /// Ride in progress - passenger picked up
    case rideInProgress

    /// Approaching destination (< 1 min away)
    case approachingDestination

    /// Ride completed successfully
    case rideCompleted
}
