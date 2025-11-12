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
struct LocationPoint: Identifiable, Equatable {
    /// Unique identifier for the location point
    let id = UUID()

    /// Geographic coordinates of the location
    var coordinate: CLLocationCoordinate2D

    /// Optional display name for the location
    var name: String?

    // Custom Equatable conformance since CLLocationCoordinate2D doesn't conform to Equatable by default
    static func == (lhs: LocationPoint, rhs: LocationPoint) -> Bool {
        lhs.id == rhs.id &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.name == rhs.name
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
}
