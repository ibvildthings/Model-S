//
//  RideRequestError.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import Foundation

/// Errors that can occur during ride request flow
enum RideRequestError: LocalizedError {
    case locationPermissionDenied
    case locationServicesDisabled
    case locationUnavailable
    case geocodingFailed
    case routeCalculationFailed
    case invalidPickupLocation
    case invalidDestinationLocation
    case networkUnavailable
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .locationPermissionDenied:
            return "Location access denied. Please enable location permissions in Settings."
        case .locationServicesDisabled:
            return "Location services are disabled. Please enable them in Settings."
        case .locationUnavailable:
            return "Unable to determine your location. Please try again."
        case .geocodingFailed:
            return "Unable to find this address. Please try a different location."
        case .routeCalculationFailed:
            return "Unable to calculate route. Please check your locations."
        case .invalidPickupLocation:
            return "Please enter a valid pickup location."
        case .invalidDestinationLocation:
            return "Please enter a valid destination."
        case .networkUnavailable:
            return "No internet connection. Please check your network."
        case .unknown(let error):
            return "An error occurred: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .locationPermissionDenied, .locationServicesDisabled:
            return "Open Settings to enable location access."
        case .networkUnavailable:
            return "Check your internet connection and try again."
        default:
            return "Please try again or contact support if the issue persists."
        }
    }
}
