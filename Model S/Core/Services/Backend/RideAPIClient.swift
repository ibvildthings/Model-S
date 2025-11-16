//
//  RideAPIClient.swift
//  Model S
//
//  Real HTTP client for backend server
//

import Foundation
import CoreLocation

class RideAPIClient: RideRequestService {

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

        print("🌐 RideAPIClient initialized with baseURL: \(baseURL)")
    }

    deinit {
        pollingTask?.cancel()
    }

    // MARK: - RideRequestService Protocol

    func requestRide(pickup: LocationPoint, destination: LocationPoint) async throws -> RideRequestResult {
        print("📤 Requesting ride from backend...")
        print("   Pickup: \(pickup.coordinate.latitude), \(pickup.coordinate.longitude)")
        print("   Destination: \(destination.coordinate.latitude), \(destination.coordinate.longitude)")

        // Prepare request
        let url = URL(string: "\(baseURL)/api/rides/request")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Create payload
        let payload = RideRequestPayload(
            pickup: LocationPayload(from: pickup),
            destination: LocationPayload(from: destination)
        )

        request.httpBody = try JSONEncoder().encode(payload)

        // Send request with automatic retry on network failures
        let (data, response) = try await performRequestWithRetry {
            try await self.session.data(for: request)
        }

        // Check HTTP status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RideRequestError.networkUnavailable
        }

        print("📥 Response status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
            // Try to decode error message
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                print("❌ Backend error: \(errorResponse.message)")
                throw RideRequestError.rideRequestFailed
            }
            print("❌ Unexpected status code: \(httpResponse.statusCode)")
            throw RideRequestError.rideRequestFailed
        }

        // Debug: Print raw response
        if let responseString = String(data: data, encoding: .utf8) {
            print("📦 Raw response: \(responseString)")
        }

        // Decode response
        do {
            let rideResponse = try JSONDecoder().decode(RideResponse.self, from: data)
            print("✅ Ride created: \(rideResponse.rideId)")
            print("   Status: \(rideResponse.status)")
        } catch {
            print("❌ JSON Decoding Error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   Missing key: \(key.stringValue) - \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("   Type mismatch: \(type) - \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("   Value not found: \(type) - \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("   Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("   Unknown decoding error")
                }
            }
            throw RideRequestError.rideRequestFailed
        }

        // Decode response
        let rideResponse = try JSONDecoder().decode(RideResponse.self, from: data)
        print("✅ Ride created: \(rideResponse.rideId)")
        print("   Status: \(rideResponse.status)")

        // Note: Polling for driver assignment is now handled by RideFlowController
        // to properly communicate state changes to the UI

        return RideRequestResult(
            rideId: rideResponse.rideId,
            driver: nil, // Driver will be assigned asynchronously
            status: convertStatus(rideResponse.status),
            estimatedArrival: nil
        )
    }

    func getRideStatus(rideId: String) async throws -> RideRequestResult {
        let url = URL(string: "\(baseURL)/api/rides/\(rideId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Use retry logic for status polling (more lenient - status checks are frequent)
        let (data, response) = try await performRequestWithRetry(maxRetries: 2) {
            try await self.session.data(for: request)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RideRequestError.rideRequestFailed
        }

        let rideResponse = try JSONDecoder().decode(RideResponse.self, from: data)

        // Convert driver if available
        let driver: DriverInfo? = rideResponse.driver.map { driverResponse in
            driverResponse.toDriverInfo(estimatedArrival: rideResponse.estimatedArrival)
        }

        if let driver = driver {
            print("🚗 Driver info received:")
            print("   Name: \(driver.name)")
            print("   Location: \(driver.currentLocation?.latitude ?? 0), \(driver.currentLocation?.longitude ?? 0)")
            print("   ETA: \(driver.estimatedArrivalTime ?? 0)s")
        }

        return RideRequestResult(
            rideId: rideResponse.rideId,
            driver: driver,
            status: convertStatus(rideResponse.status),
            estimatedArrival: rideResponse.estimatedArrival
        )
    }

    func cancelRide(rideId: String) async throws {
        print("🚫 Cancelling ride: \(rideId)")

        let url = URL(string: "\(baseURL)/api/rides/\(rideId)/cancel")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Use retry logic for cancellation (important to succeed)
        let (_, response) = try await performRequestWithRetry {
            try await self.session.data(for: request)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RideRequestError.rideRequestFailed
        }

        // Stop polling
        pollingTask?.cancel()

        print("✅ Ride cancelled successfully")
    }

    // MARK: - Polling

    private func startPollingForDriverAssignment(rideId: String) {
        // Cancel any existing polling
        pollingTask?.cancel()

        print("🔄 Starting to poll for driver assignment...")

        pollingTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Poll every 1 second for driver assignment
            var attempts = 0
            let maxAttempts = 30 // Poll for up to 30 seconds

            while !Task.isCancelled && attempts < maxAttempts {
                attempts += 1

                do {
                    // Wait 1 second between polls
                    try await Task.sleep(nanoseconds: 1_000_000_000)

                    let status = try await self.getRideStatus(rideId: rideId)

                    // Check if driver has been assigned
                    if status.driver != nil {
                        print("✅ Driver assigned after \(attempts) attempts!")
                        // Polling will continue to get status updates
                        // but at a slower rate now

                        // Continue polling at slower rate for status updates
                        while !Task.isCancelled {
                            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                            _ = try await self.getRideStatus(rideId: rideId)
                        }

                        break
                    } else {
                        print("⏳ Waiting for driver... (attempt \(attempts))")
                    }
                } catch {
                    print("❌ Polling error: \(error)")
                    break
                }
            }

            if attempts >= maxAttempts {
                print("⚠️ No driver assigned after \(maxAttempts) seconds")
            }
        }
    }

    // MARK: - Helper Methods

    /// Performs a network request with automatic retry on transient failures
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - operation: The async operation to perform
    /// - Returns: The result of the operation
    /// - Throws: The last error encountered if all retries fail
    private func performRequestWithRetry<T>(
        maxRetries: Int = 3,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                // Attempt the operation
                let result = try await operation()

                // Success! Log if this was a retry
                if attempt > 0 {
                    print("✅ Request succeeded after \(attempt) retries")
                }

                return result

            } catch {
                lastError = error

                // Check if error is retryable
                let shouldRetry = isRetryableError(error)

                // Don't retry on last attempt or non-retryable errors
                if attempt >= maxRetries || !shouldRetry {
                    if !shouldRetry {
                        print("❌ Non-retryable error encountered: \(error)")
                    } else {
                        print("❌ Max retries (\(maxRetries)) exceeded")
                    }
                    throw error
                }

                // Calculate exponential backoff delay: 0.5s, 1s, 2s, 4s
                let baseDelay: TimeInterval = 0.5
                let delay = baseDelay * pow(2.0, Double(attempt))

                print("⚠️ Request failed (attempt \(attempt + 1)/\(maxRetries + 1)): \(error)")
                print("🔄 Retrying in \(delay)s...")

                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        // This should never be reached, but Swift requires it
        throw lastError ?? RideRequestError.networkUnavailable
    }

    /// Determines if an error is retryable (network issues) vs non-retryable (client errors)
    private func isRetryableError(_ error: Error) -> Bool {
        // Network errors are retryable
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

        // HTTP 5xx errors are retryable (server issues)
        // HTTP 4xx errors are NOT retryable (client errors)
        // For now, we'll handle this at the URLSession level above

        return false
    }

    private func convertStatus(_ status: String) -> RideRequestState {
        switch status.lowercased() {
        case "searching":
            return .searchingForDriver
        case "assigned":
            return .driverFound
        case "enroute", "en_route":
            return .driverEnRoute
        case "arriving":
            return .driverArriving
        case "inprogress", "in_progress":
            return .rideInProgress
        case "approaching", "approachingdestination":
            return .approachingDestination
        case "completed":
            return .rideCompleted
        default:
            print("⚠️ Unknown backend status: \(status), defaulting to searchingForDriver")
            return .searchingForDriver
        }
    }
}
