//
//  RideHistory.swift
//  Model S
//
//  Created by Claude Code
//

import Foundation
import CoreLocation

/// Represents a completed ride in the history
struct RideHistory: Identifiable, Codable, Equatable {
    let id: UUID
    let pickupLocation: LocationPoint
    let destinationLocation: LocationPoint
    let distance: Double // in meters
    let estimatedTravelTime: TimeInterval // in seconds
    let timestamp: Date
    let pickupAddress: String
    let destinationAddress: String

    init(
        id: UUID = UUID(),
        pickupLocation: LocationPoint,
        destinationLocation: LocationPoint,
        distance: Double,
        estimatedTravelTime: TimeInterval,
        timestamp: Date = Date(),
        pickupAddress: String,
        destinationAddress: String
    ) {
        self.id = id
        self.pickupLocation = pickupLocation
        self.destinationLocation = destinationLocation
        self.distance = distance
        self.estimatedTravelTime = estimatedTravelTime
        self.timestamp = timestamp
        self.pickupAddress = pickupAddress
        self.destinationAddress = destinationAddress
    }

    /// Formatted distance string (e.g., "2.5 mi" or "1.2 km")
    var formattedDistance: String {
        let miles = distance * 0.000621371
        return String(format: "%.1f mi", miles)
    }

    /// Formatted travel time string (e.g., "15 min")
    var formattedTravelTime: String {
        let minutes = Int(estimatedTravelTime / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }

    /// Formatted timestamp string (e.g., "Today at 3:45 PM" or "Dec 15, 2024")
    var formattedDate: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(timestamp) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: timestamp))"
        } else if calendar.isDateInYesterday(timestamp) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Yesterday at \(formatter.string(from: timestamp))"
        } else if calendar.isDate(timestamp, equalTo: now, toGranularity: .year) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d 'at' h:mm a"
            return formatter.string(from: timestamp)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: timestamp)
        }
    }
}
