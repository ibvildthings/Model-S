//
//  RideRequestViewModel.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import Foundation
import MapKit
import Combine

/// Main ViewModel for managing ride request business logic
@MainActor
class RideRequestViewModel: ObservableObject {
    @Published var pickupLocation: LocationPoint?
    @Published var destinationLocation: LocationPoint?
    @Published var pickupAddress: String = ""
    @Published var destinationAddress: String = ""
    @Published var route: MKRoute?
    @Published var rideState: RideRequestState = .selectingPickup
    @Published var error: RideRequestError?
    @Published var isLoading: Bool = false
    @Published var estimatedTravelTime: TimeInterval?
    @Published var estimatedDistance: CLLocationDistance?

    // Driver-related properties
    @Published var currentDriver: DriverInfo?
    @Published var currentRideId: String?
    @Published var estimatedDriverArrival: TimeInterval?

    private var geocodingService: any GeocodingService
    private var routeService: any RouteCalculationService
    private let rideRequestService: any RideRequestService
    private var cancellables = Set<AnyCancellable>()

    init(rideRequestService: (any RideRequestService)? = nil) {
        // Create services from factory
        self.geocodingService = MapServiceFactory.shared.createGeocodingService()
        self.routeService = MapServiceFactory.shared.createRouteCalculationService()
        self.rideRequestService = rideRequestService ?? RideRequestServiceFactory.shared.createRideRequestService(useMock: true)

        // Observe provider changes and recalculate route when provider switches
        MapProviderPreference.shared.$selectedProvider
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    // Recreate services with new provider
                    self.geocodingService = MapServiceFactory.shared.createGeocodingService()
                    self.routeService = MapServiceFactory.shared.createRouteCalculationService()
                    // Recalculate route if both locations are set
                    if let pickup = self.pickupLocation, let destination = self.destinationLocation {
                        await self.calculateRoute(from: pickup.coordinate, to: destination.coordinate)
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Geocoding

    /// Convert address string to coordinates
    func geocodeAddress(_ address: String, isPickup: Bool) async {
        guard !address.isEmpty else { return }

        isLoading = true
        error = nil

        do {
            let (coordinate, formattedAddress) = try await geocodingService.geocode(address: address)

            let locationPoint = LocationPoint(
                coordinate: coordinate,
                name: formattedAddress
            )

            if isPickup {
                pickupLocation = locationPoint
                pickupAddress = formattedAddress
            } else {
                destinationLocation = locationPoint
                destinationAddress = formattedAddress
            }

            // Calculate route if both locations are set
            if pickupLocation != nil && destinationLocation != nil {
                await calculateRoute()
            }

            isLoading = false
        } catch {
            self.error = .geocodingFailed
            isLoading = false
        }
    }

    /// Convert coordinates to address string
    func reverseGeocodeLocation(_ coordinate: CLLocationCoordinate2D, isPickup: Bool) async {
        isLoading = true
        error = nil

        do {
            let address = try await geocodingService.reverseGeocode(coordinate: coordinate)

            if isPickup {
                pickupAddress = address
                pickupLocation = LocationPoint(coordinate: coordinate, name: address)
            } else {
                destinationAddress = address
                destinationLocation = LocationPoint(coordinate: coordinate, name: address)
            }

            isLoading = false
        } catch {
            self.error = .geocodingFailed
            isLoading = false
        }
    }

    // MARK: - Route Calculation

    /// Calculate route using route service (abstracted)
    func calculateRoute() async {
        guard let pickup = pickupLocation,
              let destination = destinationLocation else {
            return
        }

        isLoading = true
        error = nil

        do {
            let routeResult = try await routeService.calculateRoute(
                from: pickup.coordinate,
                to: destination.coordinate
            )

            // Extract route object (MKRoute for Apple, GMSRoute for Google in future)
            self.route = routeResult.polyline as? MKRoute
            self.estimatedTravelTime = routeResult.expectedTravelTime
            self.estimatedDistance = routeResult.distance
            self.rideState = .routeReady

            isLoading = false
        } catch {
            self.error = .routeCalculationFailed
            isLoading = false
        }
    }

    // MARK: - Validation

    /// Validate that locations are ready for ride request
    func validateLocations() -> Bool {
        guard pickupLocation != nil else {
            error = .invalidPickupLocation
            return false
        }

        guard destinationLocation != nil else {
            error = .invalidDestinationLocation
            return false
        }

        return true
    }

    // MARK: - Ride Request

    /// Request a ride and handle the full flow: searching -> driver found -> en route
    func requestRide() async {
        guard let pickup = pickupLocation,
              let destination = destinationLocation else {
            error = .invalidPickupLocation
            return
        }

        do {
            // Step 1: Initial ride request
            print("🚗 Step 1: Requesting ride...")
            rideState = .rideRequested
            let initialResult = try await rideRequestService.requestRide(
                pickup: pickup,
                destination: destination
            )
            currentRideId = initialResult.rideId
            print("🚗 Ride ID: \(initialResult.rideId)")

            // Step 2: Transition to searching state
            print("🚗 Step 2: Searching for driver...")
            rideState = .searchingForDriver

            // Step 3: Poll for status updates (simulates waiting for driver assignment)
            print("🚗 Step 3: Polling for driver status...")
            let statusResult = try await rideRequestService.getRideStatus(rideId: initialResult.rideId)
            print("🚗 Status received: \(statusResult.status)")

            // Step 4: Driver found - update state and driver info
            if statusResult.status == .driverFound {
                print("🚗 Step 4: Driver found - \(statusResult.driver?.name ?? "Unknown")")
                currentDriver = statusResult.driver
                estimatedDriverArrival = statusResult.estimatedArrival
                rideState = .driverFound

                // Step 5: Wait a moment, then transition to driver en route
                print("🚗 Step 5: Waiting before transitioning to en route...")
                try await Task.sleep(nanoseconds: UInt64(2.0 * 1_000_000_000))
                print("🚗 Step 6: Driver is now en route!")
                rideState = .driverEnRoute

                // Update ETA for en route
                if let arrival = estimatedDriverArrival {
                    estimatedDriverArrival = arrival - 60 // 1 minute less
                }
            }

        } catch {
            print("❌ Error requesting ride: \(error)")
            self.error = .rideRequestFailed
            rideState = .routeReady // Reset to allow retry
        }
    }

    /// Cancel the current ride
    func cancelCurrentRide() async {
        guard let rideId = currentRideId else { return }

        do {
            try await rideRequestService.cancelRide(rideId: rideId)
            resetRideState()
        } catch {
            self.error = .rideRequestFailed
        }
    }

    /// Reset ride-specific state (keeps pickup/destination)
    func resetRideState() {
        currentDriver = nil
        currentRideId = nil
        estimatedDriverArrival = nil
        rideState = .routeReady
    }

    // MARK: - State Management

    /// Reset to initial state
    func reset() {
        pickupLocation = nil
        destinationLocation = nil
        pickupAddress = ""
        destinationAddress = ""
        route = nil
        rideState = .selectingPickup
        error = nil
        isLoading = false
        estimatedTravelTime = nil
        estimatedDistance = nil
        currentDriver = nil
        currentRideId = nil
        estimatedDriverArrival = nil
    }

    /// Cancel current ride request
    func cancelRideRequest() {
        if rideState == .rideRequested {
            rideState = .routeReady
        }
    }

    // MARK: - Formatting Helpers

    /// Format travel time for display
    func formattedTravelTime() -> String? {
        guard let time = estimatedTravelTime else { return nil }
        let minutes = Int(time / 60)
        return "\(minutes) min"
    }

    /// Format distance for display
    func formattedDistance() -> String? {
        guard let distance = estimatedDistance else { return nil }
        let miles = distance / 1609.34 // Convert meters to miles
        return String(format: "%.1f mi", miles)
    }
}
