//
//  AppStateStore.swift
//  Model S
//
//  Global application state store (Single Source of Truth)
//  Uses Redux-like pattern with actions for predictable state mutations
//

import Foundation
import CoreLocation
import Combine

// MARK: - App State

/// Global application state
/// All app-wide state lives here for predictable, observable state management
@MainActor
class AppStateStore: ObservableObject {

    // MARK: - Shared Instance

    /// Shared instance for global access
    /// Use dependency injection when possible, but this ensures a single source of truth
    static let shared = AppStateStore()

    // MARK: - User State

    /// Current authenticated user
    @Published private(set) var currentUser: User?

    /// Whether user is authenticated
    @Published private(set) var isAuthenticated: Bool = false

    // MARK: - Location State

    /// User's current location (from GPS)
    @Published private(set) var currentLocation: CLLocationCoordinate2D?

    /// Whether location services are authorized
    @Published private(set) var locationAuthorized: Bool = false

    // MARK: - Ride State

    /// Current ride state (delegated to RideFlowController)
    /// This is exposed at app level for global observers (notifications, analytics, etc.)
    @Published private(set) var currentRideState: RideState = .idle

    // MARK: - App Configuration

    /// Selected map provider (Apple Maps or Google Maps)
    @Published private(set) var mapProvider: MapProvider = .apple

    /// App is in driver mode vs rider mode
    @Published private(set) var isDriverMode: Bool = false

    // MARK: - Network State

    /// Whether app has network connectivity
    @Published private(set) var isNetworkAvailable: Bool = true

    // MARK: - Initialization

    private init() {
        // Load persisted state if needed
        loadPersistedState()
    }

    // MARK: - Actions (Redux-like)

    /// Dispatch an action to mutate state
    /// All state changes should go through this method for predictability
    func dispatch(_ action: AppAction) {
        switch action {
        // User Actions
        case .setUser(let user):
            currentUser = user
            isAuthenticated = user != nil
            print("📱 User state updated: \(user?.name ?? "nil")")

        case .logout:
            currentUser = nil
            isAuthenticated = false
            // Reset ride state on logout
            currentRideState = .idle
            print("📱 User logged out")

        // Location Actions
        case .updateLocation(let location):
            currentLocation = location

        case .setLocationAuthorization(let authorized):
            locationAuthorized = authorized
            print("📱 Location authorization: \(authorized)")

        // Ride Actions
        case .updateRideState(let newState):
            currentRideState = newState
            print("📱 Ride state updated: \(stateDescription(newState))")

        // Configuration Actions
        case .setMapProvider(let provider):
            mapProvider = provider
            // Persist preference
            UserDefaults.standard.set(provider == .apple ? "apple" : "google", forKey: "selectedMapProvider")
            print("📱 Map provider changed to: \(provider)")

        case .setDriverMode(let enabled):
            isDriverMode = enabled
            print("📱 Driver mode: \(enabled)")

        // Network Actions
        case .setNetworkAvailability(let available):
            isNetworkAvailable = available
            print("📱 Network availability: \(available)")
        }
    }

    // MARK: - Persistence

    /// Load persisted state from UserDefaults
    private func loadPersistedState() {
        // Load map provider preference
        if let savedProvider = UserDefaults.standard.string(forKey: "selectedMapProvider") {
            mapProvider = savedProvider == "google" ? .google : .apple
        }

        // Load driver mode preference
        isDriverMode = UserDefaults.standard.bool(forKey: "isDriverMode")

        // Note: User authentication should be loaded by an AuthService
        // Location should be provided by a LocationService
    }

    // MARK: - Helper Methods

    /// Get human-readable description of ride state
    private func stateDescription(_ state: RideState) -> String {
        switch state {
        case .idle: return "Idle"
        case .selectingLocations: return "Selecting Locations"
        case .routeReady: return "Route Ready"
        case .submittingRequest: return "Submitting Request"
        case .searchingForDriver: return "Searching for Driver"
        case .driverAssigned: return "Driver Assigned"
        case .driverEnRoute: return "Driver En Route"
        case .driverArriving: return "Driver Arriving"
        case .rideInProgress: return "Ride In Progress"
        case .approachingDestination: return "Approaching Destination"
        case .rideCompleted: return "Ride Completed"
        case .error(let error, _): return "Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - User Model

/// Represents an authenticated user
struct User: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let email: String
    let phoneNumber: String?
    let photoURL: String?
    let isDriver: Bool

    init(
        id: String,
        name: String,
        email: String,
        phoneNumber: String? = nil,
        photoURL: String? = nil,
        isDriver: Bool = false
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phoneNumber = phoneNumber
        self.photoURL = photoURL
        self.isDriver = isDriver
    }
}

// MARK: - App Actions

/// All possible actions that can modify app state
/// Using enum ensures all state changes are explicit and trackable
enum AppAction {
    // User actions
    case setUser(User?)
    case logout

    // Location actions
    case updateLocation(CLLocationCoordinate2D?)
    case setLocationAuthorization(Bool)

    // Ride actions
    case updateRideState(RideState)

    // Configuration actions
    case setMapProvider(MapProvider)
    case setDriverMode(Bool)

    // Network actions
    case setNetworkAvailability(Bool)
}

// MARK: - Convenience Extensions

extension AppStateStore {
    /// Whether user has an active ride in progress
    var hasActiveRide: Bool {
        currentRideState.isActiveRide
    }

    /// Current ride ID if in an active ride
    var currentRideId: String? {
        currentRideState.rideId
    }

    /// Current driver if assigned
    var currentDriver: DriverInfo? {
        currentRideState.driver
    }
}
