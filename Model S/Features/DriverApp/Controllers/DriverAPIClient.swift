/**
 * Driver API Client
 * HTTP client for driver-related backend operations
 */

import Foundation
import CoreLocation

/// Driver API Client for backend communication
class DriverAPIClient {

    // MARK: - Configuration

    private let baseURL: String
    private let session: URLSession
    private var pollingTask: Task<Void, Never>?

    // MARK: - Initialization

    init(baseURL: String = "http://localhost:3000") {
        self.baseURL = baseURL

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)

        print("🌐 DriverAPIClient initialized with baseURL: \(baseURL)")
    }

    deinit {
        pollingTask?.cancel()
    }

    // MARK: - Authentication

    /// Login driver
    func login(driverId: String, location: CLLocationCoordinate2D) async throws -> DriverLoginResponse {
        print("📤 Logging in driver: \(driverId)")

        let url = URL(string: "\(baseURL)/api/drivers/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = DriverLoginPayload(
            driverId: driverId,
            location: LocationPayload(lat: location.latitude, lng: location.longitude)
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await performRequestWithRetry {
            try await self.session.data(for: request)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DriverAPIError.loginFailed
        }

        let loginResponse = try JSONDecoder().decode(DriverLoginResponse.self, from: data)
        print("✅ Driver logged in successfully")

        return loginResponse
    }

    /// Logout driver
    func logout(driverId: String) async throws {
        print("📤 Logging out driver: \(driverId)")

        let url = URL(string: "\(baseURL)/api/drivers/\(driverId)/logout")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (_, response) = try await performRequestWithRetry {
            try await self.session.data(for: request)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DriverAPIError.logoutFailed
        }

        print("✅ Driver logged out successfully")
    }

    // MARK: - Availability

    /// Toggle driver availability (online/offline)
    func setAvailability(driverId: String, available: Bool) async throws {
        print("📤 Setting driver availability: \(available)")

        let url = URL(string: "\(baseURL)/api/drivers/\(driverId)/availability")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = AvailabilityPayload(available: available)
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await performRequestWithRetry {
            try await self.session.data(for: request)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DriverAPIError.availabilityUpdateFailed
        }

        print("✅ Driver availability updated")
    }

    // MARK: - Location Updates

    /// Update driver location
    func updateLocation(driverId: String, location: CLLocationCoordinate2D) async throws {
        let url = URL(string: "\(baseURL)/api/drivers/\(driverId)/location")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = LocationPayload(lat: location.latitude, lng: location.longitude)
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await performRequestWithRetry(maxRetries: 1) {
            try await self.session.data(for: request)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DriverAPIError.locationUpdateFailed
        }
    }

    // MARK: - Ride Management

    /// Accept a ride request
    func acceptRide(driverId: String, rideId: String) async throws {
        print("📤 Accepting ride: \(rideId)")

        let url = URL(string: "\(baseURL)/api/drivers/\(driverId)/rides/\(rideId)/accept")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (_, response) = try await performRequestWithRetry {
            try await self.session.data(for: request)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DriverAPIError.rideAcceptFailed
        }

        print("✅ Ride accepted successfully")
    }

    /// Reject a ride request
    func rejectRide(driverId: String, rideId: String) async throws {
        print("📤 Rejecting ride: \(rideId)")

        let url = URL(string: "\(baseURL)/api/drivers/\(driverId)/rides/\(rideId)/reject")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (_, response) = try await performRequestWithRetry {
            try await self.session.data(for: request)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DriverAPIError.rideRejectFailed
        }

        print("✅ Ride rejected successfully")
    }

    /// Update ride status (arrived, picked up, completed, etc.)
    func updateRideStatus(driverId: String, rideId: String, status: String) async throws {
        print("📤 Updating ride status to: \(status)")

        let url = URL(string: "\(baseURL)/api/drivers/\(driverId)/rides/\(rideId)/status")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = RideStatusPayload(status: status)
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await performRequestWithRetry {
            try await self.session.data(for: request)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DriverAPIError.statusUpdateFailed
        }

        print("✅ Ride status updated successfully")
    }

    // MARK: - Statistics

    /// Get driver statistics
    func getStats(driverId: String) async throws -> DriverStatsResponse {
        let url = URL(string: "\(baseURL)/api/drivers/\(driverId)/stats")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await performRequestWithRetry {
            try await self.session.data(for: request)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DriverAPIError.statsFetchFailed
        }

        let statsResponse = try JSONDecoder().decode(DriverStatsResponse.self, from: data)
        return statsResponse
    }

    // MARK: - Helper Methods

    /// Performs a network request with automatic retry on transient failures
    private func performRequestWithRetry<T>(
        maxRetries: Int = 3,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                let result = try await operation()

                if attempt > 0 {
                    print("✅ Request succeeded after \(attempt) retries")
                }

                return result

            } catch {
                lastError = error

                let shouldRetry = isRetryableError(error)

                if attempt >= maxRetries || !shouldRetry {
                    if !shouldRetry {
                        print("❌ Non-retryable error encountered: \(error)")
                    } else {
                        print("❌ Max retries (\(maxRetries)) exceeded")
                    }
                    throw error
                }

                let baseDelay: TimeInterval = 0.5
                let delay = baseDelay * pow(2.0, Double(attempt))

                print("⚠️ Request failed (attempt \(attempt + 1)/\(maxRetries + 1)): \(error)")
                print("🔄 Retrying in \(delay)s...")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? DriverAPIError.networkError
    }

    /// Determines if an error is retryable
    private func isRetryableError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .dnsLookupFailed,
                 .notConnectedToInternet,
                 .badServerResponse:
                return true
            default:
                return false
            }
        }

        return false
    }
}

// MARK: - API Models

struct DriverLoginPayload: Codable {
    let driverId: String
    let location: LocationPayload?
}

struct DriverLoginResponse: Codable {
    let success: Bool
    let driver: DriverInfoResponse
    let session: SessionResponse

    struct DriverInfoResponse: Codable {
        let id: String
        let name: String
        let vehicleType: String
        let vehicleModel: String
        let licensePlate: String
        let rating: Double
        let location: LocationPayload
        let available: Bool
    }

    struct SessionResponse: Codable {
        let loginTime: String
        let totalEarnings: Double
        let completedRides: Int
    }
}

struct AvailabilityPayload: Codable {
    let available: Bool
}

struct LocationPayload: Codable {
    let lat: Double
    let lng: Double
    let address: String?

    init(lat: Double, lng: Double, address: String? = nil) {
        self.lat = lat
        self.lng = lng
        self.address = address
    }
}

struct RideStatusPayload: Codable {
    let status: String
}

struct DriverStatsResponse: Codable {
    let driver: DriverInfoResponse
    let stats: StatsInfo

    struct DriverInfoResponse: Codable {
        let id: String
        let name: String
        let rating: Double
    }

    struct StatsInfo: Codable {
        let onlineTime: TimeInterval
        let completedRides: Int
        let totalEarnings: Double
        let acceptanceRate: Double
        let rating: Double
    }
}

// MARK: - Errors

enum DriverAPIError: Error, LocalizedError {
    case networkError
    case loginFailed
    case logoutFailed
    case availabilityUpdateFailed
    case locationUpdateFailed
    case rideAcceptFailed
    case rideRejectFailed
    case statusUpdateFailed
    case statsFetchFailed

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection unavailable"
        case .loginFailed:
            return "Failed to login"
        case .logoutFailed:
            return "Failed to logout"
        case .availabilityUpdateFailed:
            return "Failed to update availability"
        case .locationUpdateFailed:
            return "Failed to update location"
        case .rideAcceptFailed:
            return "Failed to accept ride"
        case .rideRejectFailed:
            return "Failed to reject ride"
        case .statusUpdateFailed:
            return "Failed to update ride status"
        case .statsFetchFailed:
            return "Failed to fetch statistics"
        }
    }
}
