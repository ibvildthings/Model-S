//
//  Constants.swift
//  Model S
//
//  Centralized constants for magic numbers and configuration values.
//  This makes the codebase more maintainable and easier to understand.
//
//  Created by Pritesh Desai on 11/13/25.
//

import MapKit
import CoreLocation
import UIKit

// MARK: - Map Configuration

/// Constants for map display and behavior
enum MapConstants {
    /// Default map center (San Francisco, CA)
    static let defaultCenter = CLLocationCoordinate2D(
        latitude: 37.7749,
        longitude: -122.4194
    )

    /// Default map zoom level (latitude/longitude delta)
    static let defaultSpan = MKCoordinateSpan(
        latitudeDelta: 0.05,
        longitudeDelta: 0.05
    )

    /// Minimum distance in meters before location update triggers (reduces battery usage)
    static let locationUpdateDistance: CLLocationDistance = 10

    /// Search radius in miles for location autocomplete
    static let searchRadiusMiles: Double = 50.0

    /// Approximate miles per degree of latitude (used for region calculations)
    static let milesPerDegree: Double = 69.0

    // MARK: - Route Visualization

    /// Color for approach route (driver heading to pickup)
    static let approachRouteColor = UIColor.systemBlue

    /// Color for active ride route (driver heading to destination with passenger)
    static let activeRideRouteColor = UIColor.systemPurple

    /// Route line width
    static let routeLineWidth: CGFloat = 4.0
}

// MARK: - Timing Configuration

/// Constants for debouncing, delays, and timeouts
enum TimingConstants {
    /// Delay before geocoding address input (prevents API spam while typing)
    static let geocodingDebounceDelay: TimeInterval = 1.0

    /// Animation duration for map transitions
    static let mapAnimationDuration: TimeInterval = 0.4

    /// Spring animation damping for smooth pin animations
    static let springDampingFraction: Double = 0.7
}

// MARK: - UI Configuration

/// Constants for UI dimensions and styling
enum UIConstants {
    /// Pin marker size on map
    static let pinSize: CGFloat = 12

    /// Card corner radius
    static let cardCornerRadius: CGFloat = 28

    /// Standard padding for cards
    static let cardPadding: CGFloat = 20

    /// Search suggestions dropdown corner radius
    static let suggestionsCornerRadius: CGFloat = 12
}
