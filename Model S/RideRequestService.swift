//
//  RideRequestService.swift
//  Model S
//
//  Created by Pritesh Desai on 11/14/25.
//

import Foundation
import CoreLocation

// MARK: - Driver Info

/// Represents driver information
struct DriverInfo: Identifiable {
    let id: String
    let name: String
    let rating: Double
    let vehicleMake: String
    let vehicleModel: String
    let vehicleColor: String
    let licensePlate: String
    let photoURL: String?
    let phoneNumber: String?
    let currentLocation: CLLocationCoordinate2D?
    let estimatedArrivalTime: TimeInterval? // seconds until arrival
}

// MARK: - Ride Request Result

/// Represents the result of a ride request
struct RideRequestResult {
    let rideId: String
    let driver: DriverInfo?
    let status: RideRequestState
    let estimatedArrival: TimeInterval? // seconds
}

// MARK: - Ride Request Service Protocol

/// Protocol for ride request services
/// This abstraction allows easy switching between mock (for development) and real API implementations
protocol RideRequestService {
    /// Request a ride from pickup to destination
    /// - Parameters:
    ///   - pickup: Pickup location
    ///   - destination: Destination location
    /// - Returns: Initial ride request result
    func requestRide(pickup: LocationPoint, destination: LocationPoint) async throws -> RideRequestResult

    /// Poll for ride status updates
    /// - Parameter rideId: The ride identifier
    /// - Returns: Updated ride request result
    func getRideStatus(rideId: String) async throws -> RideRequestResult

    /// Cancel a ride request
    /// - Parameter rideId: The ride identifier
    func cancelRide(rideId: String) async throws
}

// MARK: - Mock Ride Request Service

/// Mock implementation of RideRequestService for development/testing
/// Simulates the ride request flow with realistic delays
class MockRideRequestService: RideRequestService {

    // MARK: - Configuration

    /// Time to wait before finding a driver (seconds)
    private let searchDelay: TimeInterval

    /// Time to wait before driver starts moving (seconds)
    private let driverFoundDelay: TimeInterval

    // MARK: - Initialization

    init(searchDelay: TimeInterval = 3.0, driverFoundDelay: TimeInterval = 2.0) {
        self.searchDelay = searchDelay
        self.driverFoundDelay = driverFoundDelay
    }

    // MARK: - RideRequestService

    func requestRide(pickup: LocationPoint, destination: LocationPoint) async throws -> RideRequestResult {
        // Simulate initial request processing
        try await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))

        // Return initial state: searching for driver
        return RideRequestResult(
            rideId: UUID().uuidString,
            driver: nil,
            status: .searchingForDriver,
            estimatedArrival: nil
        )
    }

    func getRideStatus(rideId: String) async throws -> RideRequestResult {
        // Simulate searching for driver
        try await Task.sleep(nanoseconds: UInt64(searchDelay * 1_000_000_000))

        // Create mock driver info
        let driver = createMockDriver()

        // Return driver found state
        return RideRequestResult(
            rideId: rideId,
            driver: driver,
            status: .driverFound,
            estimatedArrival: 5 * 60 // 5 minutes in seconds
        )
    }

    func cancelRide(rideId: String) async throws {
        // Simulate cancellation delay
        try await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))
    }

    // MARK: - Private Helpers

    private func createMockDriver() -> DriverInfo {
        let mockDrivers = [
            ("John Smith", "Toyota", "Camry", "Silver", "ABC-1234", 4.9),
            ("Sarah Johnson", "Honda", "Accord", "Blue", "XYZ-5678", 4.8),
            ("Michael Chen", "Tesla", "Model 3", "White", "TES-9012", 5.0),
            ("Emily Davis", "Ford", "Fusion", "Black", "FOR-3456", 4.7),
            ("David Wilson", "Chevrolet", "Malibu", "Red", "CHV-7890", 4.9)
        ]

        let randomDriver = mockDrivers.randomElement()!

        return DriverInfo(
            id: UUID().uuidString,
            name: randomDriver.0,
            rating: randomDriver.5,
            vehicleMake: randomDriver.1,
            vehicleModel: randomDriver.2,
            vehicleColor: randomDriver.3,
            licensePlate: randomDriver.4,
            photoURL: nil,
            phoneNumber: nil,
            currentLocation: nil,
            estimatedArrival: 5 * 60 // 5 minutes
        )
    }
}

// MARK: - Ride Request Service Factory

/// Factory to create ride request service instances
class RideRequestServiceFactory {
    static let shared = RideRequestServiceFactory()

    private init() {}

    /// Create a ride request service instance
    /// - Parameter useMock: If true, returns mock service. If false, returns real API service (when implemented)
    func createRideRequestService(useMock: Bool = true) -> RideRequestService {
        if useMock {
            return MockRideRequestService()
        } else {
            // TODO: Replace with real API service when backend is ready
            // return RealRideRequestService(apiClient: apiClient)
            fatalError("Real API service not yet implemented. Use mock service for now.")
        }
    }
}
