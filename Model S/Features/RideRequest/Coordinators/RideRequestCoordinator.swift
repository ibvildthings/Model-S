//
//  RideRequestCoordinator.swift
//  Model S
//
//  Glue between the ride business logic (RideFlowController, the single source
//  of truth for ride state) and the map presentation state (MapViewModel).
//
//  Data flows one way:  RideFlowController.currentState ──▶ MapViewModel
//  Views never write pickup/destination to the map directly; they call
//  `selectLocation`, the flow controller transitions, and the map is
//  re-projected from the new state.
//
//  Created by Pritesh Desai on 11/13/25.
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation
import Combine

@MainActor
class RideRequestCoordinator: ObservableObject {
    // MARK: - Owned State

    /// Ride flow controller - single source of truth for ride state
    let flowController: RideFlowController

    /// Map display state, derived from `flowController`
    let mapViewModel: MapViewModel

    // MARK: - Private

    private let configuration: RideRequestConfiguration

    /// Explicitly injected map service (tests). When nil, the provider's
    /// *current* service is used so a provider switch takes effect immediately.
    private let injectedMapService: AnyMapService?

    private var mapService: AnyMapService {
        injectedMapService ?? MapProviderService.shared.currentService
    }

    private var cancellables = Set<AnyCancellable>()
    private var autoResetTask: Task<Void, Never>?

    /// Last driver position where we calculated a route (to avoid excessive recalculations)
    private var lastRouteCalculationPosition: CLLocationCoordinate2D?

    /// Current route calculation task (cancelled when a newer position arrives)
    private var routeCalculationTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        configuration: RideRequestConfiguration = .default,
        flowController: RideFlowController? = nil,
        mapService: AnyMapService? = nil
    ) {
        self.configuration = configuration
        self.flowController = flowController ?? RideFlowController(mapService: mapService)
        self.mapViewModel = MapViewModel()
        self.injectedMapService = mapService

        setupLocationUpdates()

        // NOTE: @Published emits in willSet, so the handler must use the value it
        // is given rather than reading `flowController.currentState`.
        self.flowController.$currentState
            .sink { [weak self] newState in
                self?.handleStateChange(newState)
            }
            .store(in: &cancellables)

        // Real-time driver position from the backend
        self.flowController.$realTimeDriverLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.handleDriverPositionUpdate(location)
            }
            .store(in: &cancellables)

        // Re-render views observing the coordinator when either child changes
        self.flowController.objectWillChange
            .merge(with: mapViewModel.objectWillChange)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        self.flowController.startFlow()
    }

    deinit {
        autoResetTask?.cancel()
        routeCalculationTask?.cancel()
    }

    // MARK: - Intents (called by views)

    /// User picked a location from autocomplete, the map, or "current location"
    func selectLocation(coordinate: CLLocationCoordinate2D, name: String, isPickup: Bool) {
        let locationPoint = LocationPoint(coordinate: coordinate, name: name)
        if isPickup {
            flowController.updatePickup(locationPoint)
        } else {
            flowController.updateDestination(locationPoint)
        }
    }

    /// Validates and returns the confirmed pickup/destination, or nil if incomplete
    func confirmRide() -> (pickup: LocationPoint, destination: LocationPoint)? {
        guard let pickup = flowController.pickupLocation,
              let destination = flowController.destinationLocation else {
            return nil
        }
        return (pickup, destination)
    }

    /// Start the ride request flow
    func startRideRequest() async {
        await flowController.requestRide()
    }

    /// Cancels the current ride request
    func cancelRideRequest() {
        autoResetTask?.cancel()
        autoResetTask = nil

        Task {
            await flowController.cancelRide()
        }
    }

    /// Whether confirm slider should be visible
    var shouldShowConfirmSlider: Bool {
        flowController.shouldShowConfirmSlider
    }

    // MARK: - Location Updates

    /// Auto-fill pickup with the user's location the first time we get a fix
    private func setupLocationUpdates() {
        mapViewModel.onLocationUpdate = { [weak self] location in
            guard let self,
                  self.configuration.autoSetPickupLocation,
                  self.flowController.pickupLocation == nil else { return }

            Task {
                do {
                    let address = try await self.mapService.reverseGeocode(coordinate: location.coordinate)
                    self.selectLocation(coordinate: location.coordinate, name: address, isPickup: true)
                } catch {
                    AppLog.debug("Reverse geocoding failed: \(error)")
                }
            }
        }
    }

    // MARK: - State Projection

    /// Projects the new ride state onto the map and triggers side effects
    private func handleStateChange(_ state: RideState) {
        // Pins always mirror the flow controller's state
        if case .idle = state {
            // Keep the last pins on screen after a completed ride resets to idle
        } else {
            mapViewModel.pickupLocation = state.pickupLocation
            mapViewModel.destinationLocation = state.destinationLocation
        }

        switch state {
        case .selectingLocations:
            autoResetTask?.cancel()
            mapViewModel.clearDriverLocation()
            mapViewModel.routePolyline = nil

        case .routeReady:
            if let coordinates = flowController.routeCoordinates {
                mapViewModel.updateRoute(coordinates)
            } else {
                AppLog.warning("⚠️ No route available to display")
            }

        case .driverEnRoute(_, let driver, _, let pickup, _):
            mapViewModel.switchToApproachRoute()
            lastRouteCalculationPosition = nil

            if let driverLocation = driver.currentLocation {
                Task {
                    guard let coordinates = await flowController.calculateDriverRoute(
                        from: driverLocation,
                        to: pickup.coordinate
                    ) else { return }
                    mapViewModel.updateDriverRouteCoordinates(coordinates)
                    lastRouteCalculationPosition = driverLocation
                }
            }

        case .rideInProgress(_, let driver, _, _, let destination):
            mapViewModel.switchToActiveRideRoute()
            lastRouteCalculationPosition = nil

            if let driverLocation = driver.currentLocation {
                Task {
                    guard let coordinates = await flowController.calculateDriverRoute(
                        from: driverLocation,
                        to: destination.coordinate
                    ) else { return }
                    mapViewModel.routePolyline = coordinates
                    mapViewModel.setRegion(
                        Self.region(containing: driverLocation, and: destination.coordinate, style: .overview)
                    )
                    lastRouteCalculationPosition = driverLocation
                }
            }

        case .rideCompleted:
            // Keep the driver visible at the destination briefly, then reset
            autoResetTask?.cancel()
            autoResetTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard !Task.isCancelled else { return }
                self?.flowController.reset()
            }

        case .idle:
            autoResetTask?.cancel()
            mapViewModel.clearDriverLocation()
            mapViewModel.routePolyline = nil

        default:
            break
        }
    }

    // MARK: - Driver Tracking

    private func handleDriverPositionUpdate(_ location: CLLocationCoordinate2D) {
        mapViewModel.driverLocation = location

        // Keep the driver and their current target in frame
        if let target = currentDriverTarget()?.coordinate {
            mapViewModel.setRegion(
                Self.region(containing: location, and: target, style: .tracking),
                animationDuration: 0.5
            )
        }

        // Re-route from the current position (cancel any in-flight calculation)
        routeCalculationTask?.cancel()
        routeCalculationTask = Task {
            await updateDynamicRoute(from: location)
        }
    }

    /// Where the driver is currently heading, based on the ride phase
    private func currentDriverTarget() -> (coordinate: CLLocationCoordinate2D, isApproach: Bool)? {
        switch flowController.currentState {
        case .driverEnRoute(_, _, _, let pickup, _),
             .driverArriving(_, _, let pickup, _):
            return (pickup.coordinate, true)
        case .rideInProgress(_, _, _, _, let destination),
             .approachingDestination(_, _, _, let destination):
            return (destination.coordinate, false)
        default:
            return nil
        }
    }

    /// Recomputes the remaining route from the driver's current position
    /// (only shows the path ahead, not the part already travelled)
    private func updateDynamicRoute(from driverLocation: CLLocationCoordinate2D) async {
        if let lastPosition = lastRouteCalculationPosition,
           Self.distance(lastPosition, driverLocation) < MapConstants.dynamicRouteUpdateThreshold {
            return
        }

        guard let target = currentDriverTarget() else { return }

        guard let coordinates = await flowController.calculateDriverRoute(
            from: driverLocation,
            to: target.coordinate
        ), !Task.isCancelled else { return }

        if target.isApproach {
            // Update polyline only - no re-zoom while the driver is moving
            mapViewModel.driverRoutePolyline = coordinates
        } else {
            mapViewModel.routePolyline = coordinates
        }
        lastRouteCalculationPosition = driverLocation
    }

    // MARK: - Geometry Helpers

    private enum ZoomStyle {
        /// Continuous tracking: zooms in tightly as the driver gets close
        case tracking
        /// One-off overview when the ride starts
        case overview
    }

    private static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    /// Region centred between two points, padded according to their distance
    private static func region(
        containing a: CLLocationCoordinate2D,
        and b: CLLocationCoordinate2D,
        style: ZoomStyle
    ) -> MapRegion {
        let separation = distance(a, b)

        let padding: Double
        let minimumSpan: Double
        switch style {
        case .tracking:
            minimumSpan = 0.002
            switch separation {
            case 5000...: padding = 2.5
            case 2000..<5000: padding = 2.2
            case 500..<2000: padding = 2.0
            case 50..<500: padding = 1.8
            default: padding = 1.5
            }
        case .overview:
            minimumSpan = 0.01
            switch separation {
            case 5000...: padding = 1.5
            case 2000..<5000: padding = 1.3
            case 500..<2000: padding = 1.2
            default: padding = 1.1
            }
        }

        let center = CLLocationCoordinate2D(
            latitude: (a.latitude + b.latitude) / 2,
            longitude: (a.longitude + b.longitude) / 2
        )
        let span = MapCoordinateSpan(
            latitudeDelta: max(abs(a.latitude - b.latitude) * padding, minimumSpan),
            longitudeDelta: max(abs(a.longitude - b.longitude) * padding, minimumSpan)
        )
        return MapRegion(center: center, span: span)
    }
}
