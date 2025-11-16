//
//  RideRequestCoordinator.swift
//  Model S
//
//  Coordinator that orchestrates ride request business logic.
//  Simplifies views by centralizing all complex state management and service coordination.
//
//  Created by Pritesh Desai on 11/13/25.
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation
import Combine

/// Coordinates the entire ride request flow
/// Now uses RideFlowController for clean state management
@MainActor
class RideRequestCoordinator: ObservableObject {
    // MARK: - Published State

    /// Ride flow controller - single source of truth for ride state
    @Published private(set) var flowController: RideFlowController

    /// Map display state (published for view observation)
    @Published private(set) var mapViewModel: MapViewModel

    // MARK: - Private Dependencies

    private let configuration: RideRequestConfiguration
    private let geocodingService: GeocodingService
    private let geocodingDebouncer: Debouncer
    private var cancellables = Set<AnyCancellable>()
    private var autoResetTimer: Timer?

    /// Last driver position where we calculated a route (to avoid excessive recalculations)
    private var lastRouteCalculationPosition: CLLocationCoordinate2D?

    // MARK: - Initialization

    /// Creates a coordinator with the given configuration
    /// - Parameter configuration: UI and feature configuration
    init(configuration: RideRequestConfiguration = .default) {
        self.configuration = configuration
        self.flowController = RideFlowController()
        self.mapViewModel = MapViewModel()
        self.geocodingService = MapServiceFactory.shared.createGeocodingService()
        self.geocodingDebouncer = Debouncer(delay: TimingConstants.geocodingDebounceDelay)

        setupLocationUpdates()

        // Observe state changes (use $currentState to get value AFTER it changes)
        flowController.$currentState.sink { [weak self] newState in
            self?.objectWillChange.send()
            self?.handleStateChange(newState)
        }.store(in: &cancellables)

        // Observe real-time driver position updates from backend
        flowController.$realTimeDriverLocation.sink { [weak self] driverLocation in
            guard let self = self, let location = driverLocation else { return }
            // Update map with backend's real-time driver position
            self.mapViewModel.driverLocation = location

            // Adjust viewport to keep driver in frame (every position update)
            self.adjustViewportForDriver()

            // Dynamically update route from current position (Uber/Lyft style)
            Task {
                await self.updateDynamicRoute(from: location)
            }
        }.store(in: &cancellables)

        // Forward mapViewModel changes to coordinator's objectWillChange
        mapViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        // Start the flow
        flowController.startFlow()
    }

    // MARK: - Location Selection

    /// Handles when user selects a location from autocomplete or map
    /// - Parameters:
    ///   - coordinate: The selected coordinate
    ///   - name: The location name/address
    ///   - isPickup: Whether this is pickup (true) or destination (false)
    func selectLocation(coordinate: CLLocationCoordinate2D, name: String, isPickup: Bool) async {
        // Cancel any pending geocoding since we have exact coordinates
        geocodingDebouncer.cancel()

        // Create location point
        let locationPoint = LocationPoint(coordinate: coordinate, name: name)

        // Update flow controller state
        if isPickup {
            flowController.updatePickup(locationPoint)
            mapViewModel.updatePickupLocation(coordinate, name: name)
        } else {
            flowController.updateDestination(locationPoint)
            mapViewModel.updateDestinationLocation(coordinate, name: name)
        }

        // Update map with route if it was calculated
        if let route = flowController.routeInfo {
            // Note: We'll need to update mapViewModel when route is ready
            // For now, the route calculation happens in flowController
        }
    }

    /// Handles when user types in address field (debounced geocoding)
    /// - Parameters:
    ///   - address: The address text
    ///   - isPickup: Whether this is pickup (true) or destination (false)
    func addressTextChanged(_ address: String, isPickup: Bool) {
        guard configuration.enableGeocoding else { return }
        guard !address.isEmpty else {
            // Clear location if text is empty
            if isPickup {
                flowController.updatePickup(nil)
                mapViewModel.pickupLocation = nil
            } else {
                flowController.updateDestination(nil)
                mapViewModel.destinationLocation = nil
            }
            return
        }

        // Debounce geocoding to avoid excessive API calls while typing
        geocodingDebouncer.debounce { [weak self] in
            guard let self = self else { return }
            await self.geocodeAddress(address, isPickup: isPickup)
        }
    }

    // MARK: - Geocoding

    /// Geocodes an address (converts text to coordinates)
    private func geocodeAddress(_ address: String, isPickup: Bool) async {
        do {
            let (coordinate, formattedAddress) = try await geocodingService.geocode(address: address)
            let locationPoint = LocationPoint(coordinate: coordinate, name: formattedAddress)

            // Update flow controller
            if isPickup {
                flowController.updatePickup(locationPoint)
                mapViewModel.updatePickupLocation(coordinate, name: formattedAddress)
            } else {
                flowController.updateDestination(locationPoint)
                mapViewModel.updateDestinationLocation(coordinate, name: formattedAddress)
            }
        } catch {
            // Handle geocoding error
            print("Geocoding failed: \(error)")
        }
    }

    // MARK: - Ride Confirmation

    /// Validates and confirms the ride request
    /// - Returns: Tuple of (pickup, destination) if successful, nil if validation failed
    func confirmRide() -> (pickup: LocationPoint, destination: LocationPoint)? {
        // Validate locations exist
        guard let pickup = flowController.pickupLocation else {
            return nil
        }

        guard let destination = flowController.destinationLocation else {
            return nil
        }

        return (pickup, destination)
    }

    /// Start the ride request flow (call this from an async context)
    func startRideRequest() async {
        await flowController.requestRide()
    }

    /// Cancels the current active ride
    func cancelCurrentRide() {
        Task { @MainActor in
            await flowController.cancelRide()
        }
    }

    // MARK: - State Management

    /// Resets all state to initial values
    func reset() {
        flowController.reset()
        mapViewModel.pickupLocation = nil
        mapViewModel.destinationLocation = nil
        mapViewModel.routePolyline = nil
        geocodingDebouncer.cancel()
    }

    /// Cancels the current ride request
    func cancelRideRequest() {
        // Cancel auto-reset timer if it's running
        autoResetTimer?.invalidate()
        autoResetTimer = nil

        Task { @MainActor in
            await flowController.cancelRide()
        }
    }

    deinit {
        // Clean up timer on deallocation
        autoResetTimer?.invalidate()
    }

    // MARK: - Computed Properties

    /// Whether confirm slider should be visible
    var shouldShowConfirmSlider: Bool {
        flowController.shouldShowConfirmSlider
    }

    // MARK: - Location Updates

    /// Sets up automatic location updates from MapViewModel
    private func setupLocationUpdates() {
        mapViewModel.onLocationUpdate = { [weak self] location in
            guard let self = self else { return }

            // Auto-set pickup to current location if enabled and no pickup set yet
            if self.configuration.autoSetPickupLocation,
               self.flowController.pickupLocation == nil {
                Task {
                    do {
                        let address = try await self.geocodingService.reverseGeocode(coordinate: location.coordinate)
                        let locationPoint = LocationPoint(coordinate: location.coordinate, name: address)
                        self.flowController.updatePickup(locationPoint)
                        self.mapViewModel.updatePickupLocation(location.coordinate, name: address)
                    } catch {
                        print("Reverse geocoding failed: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - Focus Management

    /// Call when pickup field is focused
    func didFocusPickup() {
        // State management handled by flowController
    }

    /// Call when destination field is focused
    func didFocusDestination() {
        // State management handled by flowController
    }

    // MARK: - Viewport Management

    /// Adjusts viewport to keep driver and target (pickup or destination) in frame
    private func adjustViewportForDriver() {
        guard let driver = mapViewModel.driverLocation else { return }

        // Determine target based on current state
        let targetCoordinate: CLLocationCoordinate2D?

        switch flowController.currentState {
        case .driverEnRoute(_, _, _, let pickup, _), .driverArriving(_, _, let pickup, _):
            targetCoordinate = pickup.coordinate
        case .rideInProgress(_, _, _, _, let destination), .approachingDestination(_, _, _, let destination):
            targetCoordinate = destination.coordinate
        default:
            targetCoordinate = nil
        }

        guard let target = targetCoordinate else { return }

        // Calculate center point between driver and target
        let center = CLLocationCoordinate2D(
            latitude: (driver.latitude + target.latitude) / 2,
            longitude: (driver.longitude + target.longitude) / 2
        )

        // Calculate distance between driver and target
        let driverCL = CLLocation(latitude: driver.latitude, longitude: driver.longitude)
        let targetCL = CLLocation(latitude: target.latitude, longitude: target.longitude)
        let distance = driverCL.distance(from: targetCL)

        // Dynamic padding based on distance - zooms in as driver gets closer
        let paddingMultiplier: Double
        if distance > 5000 { // > 5km
            paddingMultiplier = 1.5
        } else if distance > 2000 { // 2-5km
            paddingMultiplier = 1.3
        } else if distance > 500 { // 500m-2km
            paddingMultiplier = 1.2
        } else if distance > 50 { // 50m-500m
            paddingMultiplier = 1.15
        } else { // < 50m - VERY CLOSE, minimal padding
            paddingMultiplier = 1.05 // Very tight zoom when at destination
        }

        // Calculate span
        let latDelta = abs(driver.latitude - target.latitude) * paddingMultiplier
        let lonDelta = abs(driver.longitude - target.longitude) * paddingMultiplier

        let span = MKCoordinateSpan(
            latitudeDelta: max(latDelta, 0.002), // Minimum span for very close proximity
            longitudeDelta: max(lonDelta, 0.002)
        )

        // Update viewport smoothly
        withAnimation(.easeInOut(duration: 0.5)) {
            mapViewModel.region = MKCoordinateRegion(center: center, span: span)
        }
    }

    // MARK: - State Change Handling

    /// Handles state transitions and triggers appropriate actions (like driver animation)
    private func handleStateChange(_ currentState: RideState) {
        print("🔄 handleStateChange called with state: \(currentState)")

        // Ensure map always has pickup/destination from current state
        if let pickup = flowController.pickupLocation {
            mapViewModel.updatePickupLocation(pickup.coordinate, name: pickup.name)
        }
        if let destination = flowController.destinationLocation {
            mapViewModel.updateDestinationLocation(destination.coordinate, name: destination.name)
        }

        switch currentState {
        case .routeReady:
            print("🔄 Handling .routeReady")
            // Update map with the calculated route
            if let mkRoute = flowController.currentMKRoute {
                print("📍 Updating map with calculated route")
                mapViewModel.updateRouteFromMKRoute(mkRoute)
            }

        case .driverEnRoute(_, let driver, let eta, let pickup, _):
            print("🔄 Handling .driverEnRoute")

            // NEW ARCHITECTURE: Backend position updates drive the map (no local animation)
            // The flowController's $realTimeDriverLocation publisher will update the map
            // Every poll (2s) with real GPS data from backend simulation

            // Switch to approach route mode (driver → pickup, blue color)
            mapViewModel.switchToApproachRoute()

            // Reset route calculation tracking for new approach phase
            lastRouteCalculationPosition = nil

            // Initial route calculation from driver's starting position
            if let driverLocation = driver.currentLocation {
                Task {
                    print("🚗 Calculating initial driver route from \(driverLocation) to \(pickup.coordinate)")
                    if let driverRoute = await flowController.calculateDriverRoute(
                        from: driverLocation,
                        to: pickup.coordinate
                    ) {
                        mapViewModel.updateDriverRoute(driverRoute)
                        lastRouteCalculationPosition = driverLocation
                        print("✅ Driver route displayed (will update dynamically as driver moves)")
                    }
                }
            }

        case .driverArriving(_, _, _, _):
            // Animation continues, waiting for driver to reach pickup
            print("🚗 Driver arriving soon...")
            break

        case .rideInProgress(_, let driver, let eta, let pickup, let destination):
            // Driver picked up passenger, now driving to destination
            print("🔄 Handling .rideInProgress")

            // NEW ARCHITECTURE: Backend position updates continue to drive the map
            // No local animation needed - backend sends real-time positions

            // Switch viewport to track driver + destination
            mapViewModel.switchToDestinationTracking()

            // Switch to active ride route (pickup → destination, purple color)
            mapViewModel.switchToActiveRideRoute()

            // Reset route calculation tracking for new active ride phase
            lastRouteCalculationPosition = nil

            // Calculate initial route from current position to destination
            if let driverLocation = driver.currentLocation {
                Task {
                    print("🚗 Calculating initial route from current position to \(destination.coordinate)")
                    if let destRoute = await flowController.calculateDriverRoute(
                        from: driverLocation,
                        to: destination.coordinate
                    ) {
                        mapViewModel.routePolyline = destRoute.polyline
                        lastRouteCalculationPosition = driverLocation
                        print("✅ Destination route displayed (will update dynamically as driver moves)")
                    }
                }
            }
            break

        case .approachingDestination(_, _, _, _):
            // Animation continues toward destination
            print("🏁 Approaching destination...")
            break

        case .rideCompleted:
            // Ride finished - keep driver visible at destination for completion UI
            print("✅ Ride completed - driver stays at destination")

            // DON'T clear driver immediately - they should stay at destination
            // Driver will be cleared when auto-reset happens (after 2.5 seconds)

            // Auto-reset after 2.5 seconds to allow user to see completion
            print("⏱️ Scheduling auto-reset in 2.5 seconds...")
            autoResetTimer?.invalidate()
            autoResetTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                print("🔄 Auto-resetting to idle state")
                Task { @MainActor in
                    self.flowController.reset()
                }
            }
            break

        case .idle, .selectingLocations:
            print("🔄 Handling .idle or .selectingLocations")
            // Cancel auto-reset timer if it's running
            autoResetTimer?.invalidate()
            autoResetTimer = nil

            // Clear driver location and route when going back to initial states
            mapViewModel.clearDriverLocation()
            mapViewModel.routePolyline = nil

        default:
            print("🔄 Handling default case (submittingRequest, searchingForDriver, driverAssigned, etc.)")
            break
        }
    }

    // REMOVED: Manual transition methods no longer needed
    // Backend polling now controls all state transitions
    // Animation is purely visual and doesn't trigger state changes

    // MARK: - Dynamic Route Updates

    /// Updates the route dynamically from current driver position (Uber/Lyft style)
    /// Only shows route from current position forward, not the already-traveled path
    /// - Parameter driverLocation: Current driver position
    private func updateDynamicRoute(from driverLocation: CLLocationCoordinate2D) async {
        // Check if we need to recalculate based on distance moved
        if let lastPosition = lastRouteCalculationPosition {
            let lastCL = CLLocation(latitude: lastPosition.latitude, longitude: lastPosition.longitude)
            let currentCL = CLLocation(latitude: driverLocation.latitude, longitude: driverLocation.longitude)
            let distanceMoved = lastCL.distance(from: currentCL)

            // Only recalculate if driver has moved more than threshold
            if distanceMoved < MapConstants.dynamicRouteUpdateThreshold {
                return
            }
        }

        // Determine target based on current state
        let targetCoordinate: CLLocationCoordinate2D?
        let isApproachPhase: Bool

        switch flowController.currentState {
        case .driverEnRoute(_, _, _, let pickup, _),
             .driverArriving(_, _, let pickup, _):
            // Approach phase: calculate route from current position → pickup
            targetCoordinate = pickup.coordinate
            isApproachPhase = true

        case .rideInProgress(_, _, _, _, let destination),
             .approachingDestination(_, _, _, let destination):
            // Active ride phase: calculate route from current position → destination
            targetCoordinate = destination.coordinate
            isApproachPhase = false

        default:
            // Not in a phase where we need dynamic route updates
            return
        }

        guard let target = targetCoordinate else { return }

        // Recalculate route from current driver position to target
        print("🛣️ Recalculating route from current position to \(isApproachPhase ? "pickup" : "destination")")

        if let newRoute = await flowController.calculateDriverRoute(from: driverLocation, to: target) {
            // Update the appropriate route polyline
            if isApproachPhase {
                mapViewModel.updateDriverRoute(newRoute)
            } else {
                // For active ride, update the main route polyline
                mapViewModel.routePolyline = newRoute.polyline
            }

            // Update last calculation position
            lastRouteCalculationPosition = driverLocation
            print("✅ Route updated from current position")
        }
    }
}
