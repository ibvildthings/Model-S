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

    // MARK: - Initialization

    init(controller: DriverFlowController? = nil) {
        self.controller = controller ?? DriverFlowController()

        // Subscribe to controller state changes
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Mirror controller state to view model
        controller.$currentState
            .receive(on: DispatchQueue.main)
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
        isLoading = true
        errorMessage = nil

        Task {
            await controller.login(driverId: driverId)
            isLoading = false
        }
    }

    func logout() {
        isLoading = true

        Task {
            await controller.logout()
            isLoading = false
        }
    }

    // MARK: - Availability

    func toggleAvailability() {
        Task {
            await controller.toggleAvailability()
        }
    }

    // MARK: - Ride Management

    func acceptRide() {
        isLoading = true

        Task {
            await controller.acceptRide()
            isLoading = false
        }
    }

    func rejectRide() {
        Task {
            await controller.rejectRide()
        }
    }

    func arriveAtPickup() {
        Task {
            await controller.arriveAtPickup()
        }
    }

    func pickupPassenger() {
        Task {
            await controller.pickupPassenger()
        }
    }

    func completeRide() {
        Task {
            await controller.completeRide()
        }
    }

    func finishRideSummary() {
        controller.finishRideSummary()
    }

    // MARK: - Location

    func updateLocation() {
        Task {
            await controller.updateLocation()
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
        if case .error(_, let previousState) = driverState {
            // For now, just go offline
            // In production, you might want smarter recovery
            Task {
                await controller.logout()
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
