//
//  CLLocationCoordinate2D+Equatable.swift
//  Model S
//
//  Created by Pritesh Desai on 11/13/25.
//

import CoreLocation

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
