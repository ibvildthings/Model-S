//
//  RideRequestConfiguration.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI
import MapKit

/// Configuration options for customizing the RideRequestView appearance and behavior
struct RideRequestConfiguration {
    // MARK: - Visual Customization

    /// Accent color for the slider and interactive elements
    var accentColor: Color = .blue

    /// Color for the pickup location pin
    var pickupPinColor: Color = .green

    /// Color for the destination location pin
    var destinationPinColor: Color = .blue

    /// Color for the route line between pickup and destination
    var routeLineColor: Color = .blue

    /// Width of the route line
    var routeLineWidth: CGFloat = 4

    /// Map style preference
    var mapStyle: MapStyle = .standard(elevation: .flat, emphasis: .muted)

    // MARK: - Text Customization

    /// Text displayed on the slider
    var sliderText: String = "Slide to Request"

    /// Text displayed when the ride is being requested
    var requestingText: String = "Requesting Ride..."

    /// Text displayed in the status banner when searching for driver
    var findingDriverText: String = "Finding your driver..."

    /// Default pickup location text
    var defaultPickupText: String = "Current Location"

    /// Placeholder for destination field
    var destinationPlaceholder: String = "Where to?"

    /// Card title text
    var cardTitle: String = "Plan your ride"

    // MARK: - Feature Flags

    /// Enable geocoding of addresses to coordinates
    var enableGeocoding: Bool = true

    /// Enable real route calculation using MapKit Directions
    var enableRouteCalculation: Bool = true

    /// Enable location validation before allowing ride request
    var enableValidation: Bool = true

    /// Show route information (ETA and distance)
    var showRouteInfo: Bool = true

    /// Show error messages in banner
    var showErrorBanner: Bool = true

    /// Auto-center map on user location when available
    var autoCenterOnUserLocation: Bool = true

    /// Auto-set pickup to user's current location
    var autoSetPickupLocation: Bool = true

    /// Debounce delay for geocoding in seconds (prevents too many API calls)
    var geocodingDebounceDelay: TimeInterval = 1.0

    /// Default configuration with standard Uber-style settings
    static let `default` = RideRequestConfiguration()
}
