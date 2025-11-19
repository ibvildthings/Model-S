//
//  DriverCoordinator.swift
//  Model S
//
//  Coordinator for driver-side features
//  Handles navigation for driver app, ride offers, and active rides
//

import SwiftUI
import Combine

// MARK: - Driver Coordinator

/// Coordinator for all driver-side features
/// Responsibilities:
/// - Navigate between driver screens (Home, Active Ride, Ride Offers)
/// - Observe driver state for navigation decisions
/// - Handle driver-specific flows
@MainActor
class DriverCoordinator: Coordinator, ObservableObject {

    // MARK: - Dependencies

    private let stateStore: AppStateStore
    private let dependencies: DependencyContainer

    // MARK: - Navigation State

    @Published var currentScreen: DriverScreen = .home

    // MARK: - Child Controllers

    private(set) var driverFlowController: DriverFlowController?

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
        print("🚕 DriverCoordinator starting")
        setupObservers()
        showHome()
    }

    func stop() {
        print("🚕 DriverCoordinator stopping")
        cancellables.removeAll()
    }

    // MARK: - Navigation

    func showHome() {
        currentScreen = .home

        // Create driver flow controller if needed
        if driverFlowController == nil {
            driverFlowController = DriverFlowController()
        }
    }

    func showActiveRide() {
        currentScreen = .activeRide
    }

    func showRideOffer() {
        currentScreen = .rideOffer
    }

    // MARK: - State Observation

    private func setupObservers() {
        // Observe driver mode changes
        stateStore.$isDriverMode
            .sink { [weak self] isDriverMode in
                if !isDriverMode {
                    // Switched out of driver mode
                    self?.stop()
                }
            }
            .store(in: &cancellables)

        // Could observe driver-specific state if DriverFlowController is observable
        // For now, driver state is managed by DriverFlowController internally
    }
}

// MARK: - Driver Screen Enum

/// Screens available in the driver flow
enum DriverScreen {
    case home
    case activeRide
    case rideOffer
}

// MARK: - SwiftUI Integration

/// View that integrates with DriverCoordinator
struct DriverCoordinatedView: View {
    @StateObject private var coordinator: DriverCoordinator

    init(coordinator: DriverCoordinator) {
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some View {
        Group {
            switch coordinator.currentScreen {
            case .home:
                DriverAppView()

            case .activeRide:
                // ActiveRideView would be shown when there's an active ride
                DriverAppView()

            case .rideOffer:
                // RideOfferView would be shown when there's a ride offer
                DriverAppView()
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
