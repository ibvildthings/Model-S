//
//  AppCoordinator.swift
//  Model S
//
//  Root coordinator for the entire application
//  Manages high-level navigation and feature coordination
//

import SwiftUI
import Combine

// MARK: - Coordinator Protocol

/// Base protocol for all coordinators
/// Coordinators handle ONLY navigation - no business logic or state management
protocol Coordinator {
    /// Start the coordinator's flow
    func start()

    /// Cleanup when coordinator is done
    func stop()
}

// MARK: - App Coordinator

/// Root coordinator for the entire application
/// Manages authentication flow, main app flow, and feature coordinators
@MainActor
class AppCoordinator: ObservableObject, Coordinator {

    // MARK: - Dependencies

    private let stateStore: AppStateStore
    private let dependencies: DependencyContainer

    // MARK: - Child Coordinators

    private var authCoordinator: AuthCoordinator?
    private var mainCoordinator: MainCoordinator?

    // MARK: - State

    @Published var currentScreen: AppScreen = .loading

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        stateStore: AppStateStore = .shared,
        dependencies: DependencyContainer = .shared
    ) {
        self.stateStore = stateStore
        self.dependencies = dependencies

        print("🎯 AppCoordinator initialized")
        setupObservers()
    }

    // MARK: - Coordinator Lifecycle

    func start() {
        print("🎯 AppCoordinator starting")

        // Check authentication status
        if stateStore.isAuthenticated {
            showMainApp()
        } else {
            showAuth()
        }
    }

    func stop() {
        print("🎯 AppCoordinator stopping")
        authCoordinator?.stop()
        mainCoordinator?.stop()
        cancellables.removeAll()
    }

    // MARK: - Navigation

    private func showAuth() {
        print("🎯 Showing authentication flow")
        currentScreen = .authentication
        authCoordinator = AuthCoordinator(stateStore: stateStore, dependencies: dependencies)
        authCoordinator?.start()
    }

    private func showMainApp() {
        print("🎯 Showing main app")
        currentScreen = .main
        mainCoordinator = MainCoordinator(stateStore: stateStore, dependencies: dependencies)
        mainCoordinator?.start()
    }

    // MARK: - State Observation

    private func setupObservers() {
        // Observe authentication changes
        stateStore.$isAuthenticated
            .removeDuplicates()
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.showMainApp()
                } else {
                    self?.showAuth()
                }
            }
            .store(in: &cancellables)

        // Observe driver mode changes
        stateStore.$isDriverMode
            .removeDuplicates()
            .sink { isDriverMode in
                print("🎯 Driver mode changed: \(isDriverMode)")
                // Coordinator doesn't handle this - MainCoordinator will observe and switch UI
            }
            .store(in: &cancellables)
    }
}

// MARK: - App Screen Enum

/// Represents the current high-level screen in the app
enum AppScreen {
    case loading
    case authentication
    case main
}

// MARK: - Auth Coordinator

/// Handles authentication flow (login, signup, etc.)
@MainActor
class AuthCoordinator: Coordinator {

    private let stateStore: AppStateStore
    private let dependencies: DependencyContainer

    init(stateStore: AppStateStore, dependencies: DependencyContainer) {
        self.stateStore = stateStore
        self.dependencies = dependencies
    }

    func start() {
        print("🔐 AuthCoordinator starting")
        // TODO: Show login screen
        // For now, auto-login with mock user for development
        autoLoginForDevelopment()
    }

    func stop() {
        print("🔐 AuthCoordinator stopping")
    }

    /// Auto-login for development (remove in production)
    private func autoLoginForDevelopment() {
        Task {
            // Simulate login delay
            try? await Task.sleep(nanoseconds: 500_000_000)

            let mockUser = User(
                id: "dev-user-123",
                name: "Test User",
                email: "test@example.com",
                phoneNumber: "+1234567890",
                isDriver: false
            )

            stateStore.dispatch(.setUser(mockUser))
            print("🔐 Auto-login complete")
        }
    }
}

// MARK: - Main Coordinator

/// Handles main app flow (rider/driver modes, features)
@MainActor
class MainCoordinator: Coordinator {

    private let stateStore: AppStateStore
    private let dependencies: DependencyContainer
    private var cancellables = Set<AnyCancellable>()

    init(stateStore: AppStateStore, dependencies: DependencyContainer) {
        self.stateStore = stateStore
        self.dependencies = dependencies
    }

    func start() {
        print("🏠 MainCoordinator starting")
        setupObservers()
    }

    func stop() {
        print("🏠 MainCoordinator stopping")
        cancellables.removeAll()
    }

    private func setupObservers() {
        // Observe driver mode to switch UI
        stateStore.$isDriverMode
            .removeDuplicates()
            .sink { isDriverMode in
                if isDriverMode {
                    print("🏠 Switching to driver UI")
                    // TODO: Show driver interface
                } else {
                    print("🏠 Switching to rider UI")
                    // TODO: Show rider interface
                }
            }
            .store(in: &cancellables)

        // Observe ride state for analytics/notifications
        stateStore.$currentRideState
            .removeDuplicates()
            .sink { [weak self] rideState in
                self?.handleRideStateChange(rideState)
            }
            .store(in: &cancellables)
    }

    private func handleRideStateChange(_ state: RideState) {
        // Send analytics events
        dependencies.analyticsService.track(
            event: "ride_state_changed",
            properties: ["state": stateDescription(state)]
        )

        // Show notifications for important state changes
        switch state {
        case .driverAssigned(_, let driver, _, _):
            dependencies.notificationService.showNotification(
                title: "Driver Found!",
                body: "\(driver.name) is on the way"
            )

        case .driverArriving:
            dependencies.notificationService.showNotification(
                title: "Driver Arriving",
                body: "Your driver is less than 1 minute away"
            )

        case .rideCompleted:
            dependencies.notificationService.showNotification(
                title: "Ride Completed",
                body: "Thanks for riding with us!"
            )

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

// MARK: - SwiftUI Integration

/// Root view for the app that observes AppCoordinator
struct CoordinatedAppView: View {
    @StateObject private var coordinator = AppCoordinator()

    var body: some View {
        Group {
            switch coordinator.currentScreen {
            case .loading:
                LoadingView()

            case .authentication:
                // TODO: Replace with actual auth view
                Text("Authentication")
                    .onAppear {
                        // Auth coordinator handles auto-login for now
                    }

            case .main:
                // Use existing HomeView as main screen
                HomeView()
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

/// Simple loading view
struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .foregroundColor(.secondary)
                .padding(.top)
        }
    }
}

// MARK: - Preview

#Preview {
    CoordinatedAppView()
}
