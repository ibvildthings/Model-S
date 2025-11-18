//
//  RideRequestFeature.swift
//  Model S
//
//  Public interface for the Ride Request feature module
//  Other parts of the app should only interact with this protocol
//

import Foundation
import CoreLocation
import Combine

// MARK: - Ride Request Feature Protocol

/// Public interface for the Ride Request feature
/// This is the ONLY way other modules should interact with ride requests
@MainActor
protocol RideRequestFeature {
    // MARK: - State

    /// Current ride state
    var currentState: RideState { get }

    /// Observable publisher for ride state changes
    var rideStatePublisher: AnyPublisher<RideState, Never> { get }

    /// Whether user has an active ride
    var hasActiveRide: Bool { get }

    /// Current ride ID if active
    var rideId: String? { get }

    /// Current driver if assigned
    var driver: DriverInfo? { get }

    // MARK: - Actions

    /// Start a new ride request flow
    func startRideRequest()

    /// Update pickup location
    func setPickupLocation(_ location: LocationPoint)

    /// Update destination location
    func setDestination(_ location: LocationPoint)

    /// Request a ride (after locations are set)
    func confirmAndRequestRide() async throws

    /// Cancel current ride
    func cancelRide() async throws

    /// Reset to initial state
    func reset()
}

// MARK: - Ride Request Events

/// Events emitted by the Ride Request feature
enum RideRequestEvent {
    case rideRequested(pickup: LocationPoint, destination: LocationPoint)
    case driverMatched(DriverInfo)
    case rideStarted
    case rideCompleted
    case rideCancelled
    case error(RideRequestError)
}

// MARK: - Ride Request Feature Implementation

/// Default implementation of RideRequestFeature
/// Delegates to RideFlowController for actual implementation
@MainActor
class RideRequestModule: RideRequestFeature, ObservableObject {

    // MARK: - Dependencies

    private let flowController: RideFlowController
    private let stateStore: AppStateStore

    // MARK: - Published State

    @Published private(set) var currentState: RideState

    private var cancellables = Set<AnyCancellable>()

    var rideStatePublisher: AnyPublisher<RideState, Never> {
        flowController.$currentState.eraseToAnyPublisher()
    }

    var hasActiveRide: Bool {
        currentState.isActiveRide
    }

    var rideId: String? {
        currentState.rideId
    }

    var driver: DriverInfo? {
        currentState.driver
    }

    // MARK: - Initialization

    init(flowController: RideFlowController, stateStore: AppStateStore) {
        self.flowController = flowController
        self.stateStore = stateStore
        self.currentState = flowController.currentState

        // Observe flow controller state changes
        flowController.$currentState
            .sink { [weak self] newState in
                self?.currentState = newState
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    func startRideRequest() {
        flowController.startFlow()
    }

    func setPickupLocation(_ location: LocationPoint) {
        flowController.updatePickup(location)
    }

    func setDestination(_ location: LocationPoint) {
        flowController.updateDestination(location)
    }

    func confirmAndRequestRide() async throws {
        guard case .routeReady = currentState else {
            throw RideRequestError.invalidPickupLocation
        }

        await flowController.requestRide()
    }

    func cancelRide() async throws {
        await flowController.cancelRide()
    }

    func reset() {
        flowController.reset()
    }
}

// MARK: - Feature Factory

/// Factory for creating feature module instances
@MainActor
class FeatureFactory {
    private let dependencies: DependencyContainer

    init(dependencies: DependencyContainer = .shared) {
        self.dependencies = dependencies
    }

    // MARK: - Authentication Feature

    func createAuthenticationFeature() -> AuthenticationFeature {
        let authService = MockAuthService() // Or real service
        return AuthenticationModule(
            authService: authService,
            stateStore: dependencies.stateStore
        )
    }

    // MARK: - Ride Request Feature

    func createRideRequestFeature() -> RideRequestFeature {
        let flowController = RideFlowController(
            rideService: dependencies.rideRequestService,
            mapService: dependencies.mapService,
            stateStore: dependencies.stateStore
        )

        return RideRequestModule(
            flowController: flowController,
            stateStore: dependencies.stateStore
        )
    }
}
