//
//  RiderCoordinator.swift
//  Model S
//
//  Coordinator for rider-side features
//  Handles navigation for ride requests, history, and profile
//

import SwiftUI
import Combine

// MARK: - Rider Coordinator

/// Coordinator for all rider-side features
/// Responsibilities:
/// - Navigate between rider screens (Home, RideRequest, History, Settings)
/// - Observe ride state for navigation decisions
/// - Handle deep links to rider features
@MainActor
class RiderCoordinator: Coordinator, ObservableObject {

    // MARK: - Dependencies

    private let stateStore: AppStateStore
    private let dependencies: DependencyContainer

    // MARK: - Navigation State

    @Published var currentScreen: RiderScreen = .home

    // MARK: - Child Coordinators

    private(set) var rideRequestCoordinator: RideRequestCoordinator?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        stateStore: AppStateStore,
        dependencies: DependencyContainer
    ) {
        self.stateStore = stateStore
        self.dependencies = dependencies
    }

    // MARK: - Coordinator Lifecycle

    func start() {
        print("🚗 RiderCoordinator starting")
        setupObservers()
        showHome()
    }

    func stop() {
        print("🚗 RiderCoordinator stopping")
        cancellables.removeAll()
    }

    // MARK: - Navigation

    func showHome() {
        currentScreen = .home
    }

    func showRideRequest() {
        currentScreen = .rideRequest

        // Create ride request coordinator if needed
        if rideRequestCoordinator == nil {
            // Use production configuration
            var config = RideRequestConfiguration.default
            config.enableGeocoding = true
            config.enableRouteCalculation = true
            config.enableValidation = true
            config.showRouteInfo = true

            rideRequestCoordinator = RideRequestCoordinator(
                configuration: config
            )
        }
    }

    func showHistory() {
        currentScreen = .history
    }

    func showSettings() {
        currentScreen = .settings
    }

    // MARK: - State Observation

    private func setupObservers() {
        // Observe ride state changes
        stateStore.$currentRideState
            .sink { [weak self] rideState in
                self?.handleRideStateChange(rideState)
            }
            .store(in: &cancellables)
    }

    private func handleRideStateChange(_ state: RideState) {
        // Analytics for ride state changes
        dependencies.analyticsService.track(
            event: "rider_state_changed",
            properties: ["state": stateDescription(state)]
        )

        // Auto-navigate based on state if needed
        switch state {
        case .idle:
            // Ride completed or cancelled, could stay on current screen
            break
        case .selectingLocations, .routeReady:
            // Ensure we're on ride request screen
            if currentScreen != .rideRequest {
                showRideRequest()
            }
        case .searchingForDriver, .driverAssigned, .driverEnRoute, .rideInProgress:
            // Active ride states - ensure we're on ride request screen
            if currentScreen != .rideRequest {
                showRideRequest()
            }
        default:
            break
        }
    }

    private func stateDescription(_ state: RideState) -> String {
        switch state {
        case .idle: return "idle"
        case .selectingLocations: return "selecting_locations"
        case .routeReady: return "route_ready"
        case .submittingRequest: return "submitting_request"
        case .searchingForDriver: return "searching_for_driver"
        case .driverAssigned: return "driver_assigned"
        case .driverEnRoute: return "driver_en_route"
        case .driverArriving: return "driver_arriving"
        case .rideInProgress: return "ride_in_progress"
        case .approachingDestination: return "approaching_destination"
        case .rideCompleted: return "ride_completed"
        case .error: return "error"
        }
    }
}

// MARK: - Rider Screen Enum

/// Screens available in the rider flow
enum RiderScreen {
    case home
    case rideRequest
    case history
    case settings
}

// MARK: - SwiftUI Integration

/// View that integrates with RiderCoordinator
struct RiderCoordinatedView: View {
    @StateObject private var coordinator: RiderCoordinator

    init(coordinator: RiderCoordinator) {
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some View {
        Group {
            switch coordinator.currentScreen {
            case .home:
                HomeView()

            case .rideRequest:
                if let rideCoordinator = coordinator.rideRequestCoordinator {
                    ProductionExampleView(
                        coordinator: rideCoordinator,
                        onRideConfirmed: { _, _, _ in
                            // Ride confirmed - handled by coordinator
                        },
                        onCancel: {
                            // Cancelled - navigate back to home
                            coordinator.showHome()
                        }
                    )
                } else {
                    Text("Loading ride request...")
                }

            case .history:
                RideHistoryView()

            case .settings:
                MapProviderSettingsView()
            }
        }
        .onAppear {
            coordinator.start()
        }
        .onDisappear {
            coordinator.stop()
        }
    }
}
