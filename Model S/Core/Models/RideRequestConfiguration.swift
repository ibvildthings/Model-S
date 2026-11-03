//
//  RideRequestConfiguration.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI
import MapKit

/// Appearance and behaviour options for the rider booking screen
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

    // MARK: - Text Customization

    /// Text displayed on the slider
    var sliderText: String = "Slide to Request"

    /// Text displayed when the ride is being requested
    var requestingText: String = "Requesting Ride..."

    /// Placeholder for destination field
    var destinationPlaceholder: String = "Where to?"

    /// Card title text
    var cardTitle: String = "Plan your ride"

    // MARK: - Behaviour

    /// Auto-set pickup to user's current location
    var autoSetPickupLocation: Bool = false

    /// Default configuration with standard Uber-style settings
    static let `default` = RideRequestConfiguration()
}
