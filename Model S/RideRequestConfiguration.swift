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
    /// Accent color for the slider and interactive elements
    var accentColor: Color = .blue

    /// Color for the pickup location pin
    var pickupPinColor: Color = .green

    /// Color for the destination location pin
    var destinationPinColor: Color = .blue

    /// Text displayed on the slider
    var sliderText: String = "Slide to Request"

    /// Text displayed when the ride is being requested
    var requestingText: String = "Requesting Ride..."

    /// Text displayed in the status banner when searching for driver
    var findingDriverText: String = "Finding your driver..."

    /// Map style preference
    var mapStyle: MapStyle = .standard(elevation: .flat, emphasis: .muted)

    /// Default pickup location text
    var defaultPickupText: String = "Current Location"

    /// Placeholder for destination field
    var destinationPlaceholder: String = "Where to?"

    /// Card title text
    var cardTitle: String = "Plan your ride"

    /// Default configuration with standard Uber-style settings
    static let `default` = RideRequestConfiguration()
}
