//
//  Models.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import Foundation
import CoreLocation

// MARK: - LocationPoint
struct LocationPoint: Identifiable, Equatable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
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
enum RideRequestState {
    case selectingPickup
    case selectingDestination
    case routeReady
    case rideRequested
}
