//
//  BackendConfiguration.swift
//  Model S
//
//  Single place that decides which backend the app talks to.
//
//  Override at runtime via the Xcode scheme (Edit Scheme → Run → Arguments →
//  Environment Variables):
//    BACKEND_BASE_URL   e.g. http://192.168.1.20:3000 when running on a device
//    USE_MOCK_BACKEND   set to 1 to use MockRideRequestService (no server needed)
//

import Foundation

enum BackendConfiguration {

    /// Default backend for the simulator (see backend/README.md)
    static let defaultBaseURL = "http://localhost:3000"

    /// Base URL of the Node backend
    static var baseURL: String {
        let override = ProcessInfo.processInfo.environment["BACKEND_BASE_URL"]
        if let override, !override.isEmpty {
            return override
        }
        return defaultBaseURL
    }

    /// Whether the rider flow should use the in-process mock instead of the backend
    static var useMockRideService: Bool {
        ProcessInfo.processInfo.environment["USE_MOCK_BACKEND"] == "1"
    }

    /// Creates the rider-side ride service according to the configuration above
    static func makeRideRequestService() -> RideRequestService {
        useMockRideService ? MockRideRequestService() : RideAPIClient(baseURL: baseURL)
    }
}
