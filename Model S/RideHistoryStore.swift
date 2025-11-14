//
//  RideHistoryStore.swift
//  Model S
//
//  Created by Claude Code
//

import Foundation

/// Service responsible for persisting and retrieving ride history
/// Uses UserDefaults for simple, persistent storage across app installs
class RideHistoryStore: ObservableObject {
    static let shared = RideHistoryStore()

    @Published private(set) var rides: [RideHistory] = []

    private let userDefaultsKey = "com.modelS.rideHistory"
    private let maxHistoryItems = 100 // Limit to prevent storage bloat

    private init() {
        loadRides()
    }

    /// Add a new ride to history
    func addRide(_ ride: RideHistory) {
        rides.insert(ride, at: 0) // Insert at beginning for chronological order

        // Limit history to maxHistoryItems
        if rides.count > maxHistoryItems {
            rides = Array(rides.prefix(maxHistoryItems))
        }

        saveRides()
    }

    /// Remove a ride from history
    func removeRide(_ ride: RideHistory) {
        rides.removeAll { $0.id == ride.id }
        saveRides()
    }

    /// Remove a ride by ID
    func removeRide(withId id: UUID) {
        rides.removeAll { $0.id == id }
        saveRides()
    }

    /// Clear all ride history
    func clearAllRides() {
        rides.removeAll()
        saveRides()
    }

    /// Get rides filtered by date range
    func getRides(from startDate: Date, to endDate: Date) -> [RideHistory] {
        rides.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    /// Get total distance traveled across all rides
    var totalDistance: Double {
        rides.reduce(0) { $0 + $1.distance }
    }

    /// Get total rides count
    var totalRidesCount: Int {
        rides.count
    }

    // MARK: - Private Methods

    private func loadRides() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            rides = []
            return
        }

        do {
            let decoder = JSONDecoder()
            rides = try decoder.decode([RideHistory].self, from: data)
        } catch {
            print("❌ Failed to decode ride history: \(error)")
            rides = []
        }
    }

    private func saveRides() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(rides)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("❌ Failed to encode ride history: \(error)")
        }
    }
}
