//
//  DependencyContainer.swift
//  Model S
//
//  Centralized dependency injection container
//  Manages service creation, configuration, and lifetimes
//

import Foundation
import CoreLocation
import MapKit

// MARK: - Dependency Container

/// Central container for all app dependencies
/// Use this to inject services into feature modules for clean, testable architecture
@MainActor
class DependencyContainer {

    // MARK: - Shared Instance

    /// Shared container for app-wide access
    static let shared = DependencyContainer()

    // MARK: - State Store

    /// Global app state store (single source of truth)
    let stateStore: AppStateStore

    // MARK: - Service Configuration

    private let mapServiceConfig: MapServiceConfiguration
    private let rideServiceConfig: RideServiceConfiguration

    // MARK: - Lazy Service Instances

    /// Location service (singleton)
    private(set) lazy var locationService: LocationService = {
        createLocationService()
    }()

    /// Map service (recreated when provider changes)
    private var _mapService: AnyMapService?
    var mapService: AnyMapService {
        if let existing = _mapService {
            return existing
        }
        let service = createMapService()
        _mapService = service
        return service
    }

    /// Ride request service (singleton)
    private(set) lazy var rideRequestService: RideRequestService = {
        createRideRequestService()
    }()

    /// Notification service (singleton)
    private(set) lazy var notificationService: NotificationService = {
        createNotificationService()
    }()

    /// Analytics service (singleton)
    private(set) lazy var analyticsService: AnalyticsService = {
        createAnalyticsService()
    }()

    /// Logging service (singleton)
    private(set) lazy var loggingService: LoggingService = {
        createLoggingService()
    }()

    // MARK: - Initialization

    init(
        stateStore: AppStateStore = .shared,
        mapServiceConfig: MapServiceConfiguration = .default,
        rideServiceConfig: RideServiceConfiguration = .default
    ) {
        self.stateStore = stateStore
        self.mapServiceConfig = mapServiceConfig
        self.rideServiceConfig = rideServiceConfig

        print("🔧 DependencyContainer initialized")
    }

    // MARK: - Service Factories

    /// Create location service instance
    private func createLocationService() -> LocationService {
        print("🔧 Creating LocationService")
        return CoreLocationService(stateStore: stateStore)
    }

    /// Create map service instance
    private func createMapService() -> AnyMapService {
        let provider = stateStore.mapProvider
        print("🔧 Creating MapService for provider: \(provider)")

        switch provider {
        case .apple:
            return AnyMapService(AppleMapService())
        case .google:
            guard let apiKey = mapServiceConfig.apiKey else {
                fatalError("Google Maps API key required but not configured")
            }
            return AnyMapService(GoogleMapService(apiKey: apiKey))
        }
    }

    /// Create ride request service instance
    private func createRideRequestService() -> RideRequestService {
        print("🔧 Creating RideRequestService (useMock: \(rideServiceConfig.useMock))")

        if rideServiceConfig.useMock {
            return MockRideRequestService()
        } else {
            return RideAPIClient(baseURL: rideServiceConfig.baseURL)
        }
    }

    /// Create notification service instance
    private func createNotificationService() -> NotificationService {
        print("🔧 Creating NotificationService")
        return LocalNotificationService()
    }

    /// Create analytics service instance
    private func createAnalyticsService() -> AnalyticsService {
        print("🔧 Creating AnalyticsService")
        return ConsoleAnalyticsService()
    }

    /// Create logging service instance
    private func createLoggingService() -> LoggingService {
        print("🔧 Creating LoggingService")
        return ConsoleLoggingService()
    }

    // MARK: - Service Management

    /// Recreate map service when provider changes
    func refreshMapService() {
        print("🔧 Refreshing MapService")
        _mapService = nil
        _ = mapService // Recreate
    }

    // MARK: - Testing Support

    /// Create a mock container for testing
    static func mock(
        useMockRideService: Bool = true,
        useMockLocation: Bool = true
    ) -> DependencyContainer {
        let config = RideServiceConfiguration(
            useMock: useMockRideService,
            baseURL: "http://mock"
        )
        return DependencyContainer(
            mapServiceConfig: .apple,
            rideServiceConfig: config
        )
    }
}

// MARK: - Service Configurations

/// Configuration for ride request services
struct RideServiceConfiguration {
    let useMock: Bool
    let baseURL: String

    /// Production configuration (real backend)
    static let production = RideServiceConfiguration(
        useMock: false,
        baseURL: "http://localhost:3000"
    )

    /// Mock configuration (for development/testing)
    static let mock = RideServiceConfiguration(
        useMock: true,
        baseURL: ""
    )

    /// Default configuration - can be switched between mock and production
    static let `default` = production
}

// MARK: - Location Service Protocol

/// Protocol for location services
/// Abstracts CLLocationManager for easier testing and mock implementations
protocol LocationService {
    /// Current user location
    var currentLocation: CLLocationCoordinate2D? { get }

    /// Whether location services are authorized
    var isAuthorized: Bool { get }

    /// Request location authorization
    func requestAuthorization() async -> Bool

    /// Start tracking user location
    func startTracking()

    /// Stop tracking user location
    func stopTracking()

    /// Get current location once
    func getCurrentLocation() async throws -> CLLocationCoordinate2D
}

// MARK: - Core Location Service Implementation

/// Production implementation of LocationService using CLLocationManager
@MainActor
class CoreLocationService: NSObject, LocationService, ObservableObject {

    private let locationManager = CLLocationManager()
    private let stateStore: AppStateStore

    @Published private(set) var currentLocation: CLLocationCoordinate2D?
    @Published private(set) var isAuthorized: Bool = false

    init(stateStore: AppStateStore) {
        self.stateStore = stateStore
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        checkAuthorizationStatus()
    }

    func requestAuthorization() async -> Bool {
        locationManager.requestWhenInUseAuthorization()
        // Wait a moment for authorization
        try? await Task.sleep(nanoseconds: 500_000_000)
        checkAuthorizationStatus()
        return isAuthorized
    }

    func startTracking() {
        guard isAuthorized else {
            print("⚠️ Cannot start tracking - location not authorized")
            return
        }
        locationManager.startUpdatingLocation()
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
    }

    func getCurrentLocation() async throws -> CLLocationCoordinate2D {
        if let current = currentLocation {
            return current
        }

        // Request location once
        locationManager.requestLocation()

        // Wait for location update (with timeout)
        for _ in 0..<20 { // 2 seconds max
            if let location = currentLocation {
                return location
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }

        throw LocationError.timeout
    }

    private func checkAuthorizationStatus() {
        let status = locationManager.authorizationStatus
        isAuthorized = status == .authorizedWhenInUse || status == .authorizedAlways
        stateStore.dispatch(.setLocationAuthorization(isAuthorized))
    }
}

// MARK: - CLLocationManagerDelegate

extension CoreLocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            currentLocation = location.coordinate
            stateStore.dispatch(.updateLocation(location.coordinate))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ Location error: \(error.localizedDescription)")
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            checkAuthorizationStatus()
        }
    }
}

enum LocationError: Error {
    case timeout
    case unauthorized
}

// MARK: - Notification Service Protocol

/// Protocol for notification services
protocol NotificationService {
    /// Show a local notification
    func showNotification(title: String, body: String)

    /// Request notification permissions
    func requestAuthorization() async -> Bool
}

/// Simple console-based notification service for now
class LocalNotificationService: NotificationService {
    func showNotification(title: String, body: String) {
        print("🔔 Notification: \(title) - \(body)")
        // TODO: Implement UNUserNotificationCenter integration
    }

    func requestAuthorization() async -> Bool {
        print("🔔 Requesting notification authorization")
        // TODO: Implement UNUserNotificationCenter authorization
        return true
    }
}

// MARK: - Analytics Service Protocol

/// Protocol for analytics/tracking services
protocol AnalyticsService {
    /// Track an event
    func track(event: String, properties: [String: Any]?)

    /// Identify a user
    func identify(userId: String, traits: [String: Any]?)
}

/// Console-based analytics for development
class ConsoleAnalyticsService: AnalyticsService {
    func track(event: String, properties: [String: Any]?) {
        print("📊 Analytics event: \(event)")
        if let props = properties {
            print("   Properties: \(props)")
        }
    }

    func identify(userId: String, traits: [String: Any]?) {
        print("📊 Analytics identify: \(userId)")
        if let traits = traits {
            print("   Traits: \(traits)")
        }
    }
}

// MARK: - Logging Service Protocol

/// Protocol for logging services
protocol LoggingService {
    /// Log debug message
    func debug(_ message: String)

    /// Log info message
    func info(_ message: String)

    /// Log warning
    func warning(_ message: String)

    /// Log error
    func error(_ message: String, error: Error?)
}

/// Console-based logging for development
class ConsoleLoggingService: LoggingService {
    func debug(_ message: String) {
        print("🐛 DEBUG: \(message)")
    }

    func info(_ message: String) {
        print("ℹ️ INFO: \(message)")
    }

    func warning(_ message: String) {
        print("⚠️ WARNING: \(message)")
    }

    func error(_ message: String, error: Error?) {
        print("❌ ERROR: \(message)")
        if let error = error {
            print("   \(error.localizedDescription)")
        }
    }
}

// MARK: - Type-Erased Map Service

/// Type-erased wrapper for map services
class AnyMapService {
    private let _calculateRoute: (CLLocationCoordinate2D, CLLocationCoordinate2D) async throws -> RouteResult

    init<S: MapService>(_ service: S) {
        self._calculateRoute = service.calculateRoute
    }

    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteResult {
        try await _calculateRoute(from, to)
    }
}

// MARK: - Unified Map Service Protocol

/// Unified protocol for map services (combines all map-related functionality)
protocol MapService {
    /// Calculate route between two points
    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteResult
}

// Make existing services conform to unified protocol
extension AppleMapService: MapService {}
extension GoogleMapService: MapService {}
