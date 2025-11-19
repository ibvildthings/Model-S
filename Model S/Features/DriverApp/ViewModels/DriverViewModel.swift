/**
 * Driver View Model
 * View model for driver app UI
 * Wraps DriverFlowController and provides UI-friendly interface
 */

import Foundation
import Combine
import CoreLocation
import MapKit

@MainActor
class DriverViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Current driver state
    @Published private(set) var driverState: DriverState = .offline

    /// Loading indicator
    @Published var isLoading: Bool = false

    /// Error message (if any)
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let controller: DriverFlowController
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Background Tasks

    private var loginTask: Task<Void, Never>?
    private var logoutTask: Task<Void, Never>?
    private var actionTask: Task<Void, Never>?

    // MARK: - Initialization

    init(controller: DriverFlowController? = nil) {
        self.controller = controller ?? DriverFlowController()

        // Subscribe to controller state changes
        setupBindings()
    }

    deinit {
        loginTask?.cancel()
        logoutTask?.cancel()
        actionTask?.cancel()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Mirror controller state to view model
        // No need for .receive(on:) since both controller and viewmodel are @MainActor
        controller.$currentState
            .sink { [weak self] newState in
                self?.driverState = newState

                // Handle error state
                if case .error(let message, _) = newState {
                    self?.errorMessage = message
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Authentication

    func login(driverId: String) {
        loginTask?.cancel()
        isLoading = true
        errorMessage = nil

        loginTask = Task {
            await controller.login(driverId: driverId)
            isLoading = false
            loginTask = nil
        }
    }

    func logout() {
        logoutTask?.cancel()
        isLoading = true

        logoutTask = Task {
            await controller.logout()
            isLoading = false
            logoutTask = nil
        }
    }

    // MARK: - Availability

    func toggleAvailability() {
        actionTask?.cancel()
        actionTask = Task {
            await controller.toggleAvailability()
            actionTask = nil
        }
    }

    // MARK: - Ride Management

    func acceptRide() {
        actionTask?.cancel()
        isLoading = true

        actionTask = Task {
            await controller.acceptRide()
            isLoading = false
            actionTask = nil
        }
    }

    func rejectRide() {
        actionTask?.cancel()
        actionTask = Task {
            await controller.rejectRide()
            actionTask = nil
        }
    }

    func handleOfferExpiry() {
        actionTask?.cancel()
        actionTask = Task {
            await controller.handleOfferExpiry()
            actionTask = nil
        }
    }

    func arriveAtPickup() {
        actionTask?.cancel()
        actionTask = Task {
            await controller.arriveAtPickup()
            actionTask = nil
        }
    }

    func pickupPassenger() {
        actionTask?.cancel()
        actionTask = Task {
            await controller.pickupPassenger()
            actionTask = nil
        }
    }

    func completeRide() {
        actionTask?.cancel()
        actionTask = Task {
            await controller.completeRide()
            actionTask = nil
        }
    }

    func finishRideSummary() {
        controller.finishRideSummary()
    }

    // MARK: - Location

    func updateLocation() {
        actionTask?.cancel()
        actionTask = Task {
            await controller.updateLocation()
            actionTask = nil
        }
    }

    // MARK: - Computed Properties

    var isOnline: Bool {
        driverState.isOnline
    }

    var hasActiveRide: Bool {
        driverState.hasActiveRide
    }

    var currentStats: DriverStats? {
        driverState.currentStats
    }

    var currentRide: ActiveRide? {
        driverState.currentRide
    }

    var statusText: String {
        driverState.statusDescription
    }

    // MARK: - Error Handling

    func dismissError() {
        errorMessage = nil

        // If in error state, try to recover
        if case .error = driverState {
            // For now, just go offline
            // In production, you might want smarter recovery
            actionTask?.cancel()
            actionTask = Task {
                await controller.logout()
                actionTask = nil
            }
        }
    }
}

// MARK: - UI Helper Extensions

extension DriverViewModel {

    /// Formatted earnings text
    var earningsText: String {
        guard let stats = currentStats else {
            return "$0.00"
        }
        return String(format: "$%.2f", stats.totalEarnings)
    }

    /// Formatted online time text
    var onlineTimeText: String {
        guard let stats = currentStats else {
            return "0:00"
        }

        let hours = Int(stats.onlineTime) / 3600
        let minutes = (Int(stats.onlineTime) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Formatted completed rides text
    var completedRidesText: String {
        guard let stats = currentStats else {
            return "0"
        }
        return "\(stats.completedRides)"
    }

    /// Formatted rating text
    var ratingText: String {
        guard let stats = currentStats else {
            return "0.0"
        }
        return String(format: "%.1f", stats.rating)
    }
}
